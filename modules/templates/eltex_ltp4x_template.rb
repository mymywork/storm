class  EltexLtp4xTemplate < Switch

	attr_accessor :ontidtable
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
		@broadcastLimitAccess = 32
		@broadcastLimitTrunk = 900
		@ifacenames = { }
	end

	def templates()
		# set templates
		@me.templates("more") do 
			expect(/--More--/) do
				pinfo "More"
				send(" ")
			end
		end
	end

	def getAbsolutePort(port)
		#if x = port.match(/[a-z]+[0-9]+\/[0-9]+\/([0-9]+)/)
		#	return x[1]
		#end
		port
	end

	def getConfiguration
		slf = self
		slf.set_option("global","hostname",nil, "ltp4x")
		return
	end
	
	def getPortsStatus()
		slf = self
		self.list['ports']
	end
	def getPortError(port)
		slf = self

		self.list['ports'][port]
	end
	def clearPortCounter(port)
	end
	def setPortState(port,state)
	end
	
	def isPonPort(port)
		return true if port =~ /[0-9]+\/[0-9]+/
		return false
	end
	def getMacAddressByVlan(vlan)
		# show mac interface gpon-port 0 include s-vid 100
		@me.send("switch\r")
		wait("#")
		@me.send("show mac include vlan #{vlan}\r")
		r = self.parseMacAddress('vlan')
		@me.send("exit\r")
		wait("#")
		for c in 0..3
			self.getMacAddressOntId(c)
		end
	
		# not show switch port on epon !!!

		@mactable.each do |mac,v|
			#p mac,v
			v.each do |i|
				if i['port'] =~ /^pon-port ([0-9]+)/
					i['port'] = @ontidtable[mac] 
				end
			end
		end
		#p r
		return r
	end
	def getMacAddressByPort(port)
		# show mac interface gpon-port 0 include ont-id 2
		@me.send("switch\r")
		wait("#")
		@me.send("show mac\r")
		r = self.parseMacAddress('mac')
		@me.send("exit\r")
		wait("#")
		for c in 0..3
			self.getMacAddressOntId(c)
		end

		out = Hash.new
		@ontidtable.each do |mac,v|
		#	p mac,v
			if v == port
				if @mactable.has_key?(mac)
					out[v] = Array.new if out[v] == nil 
					out[v].push(@mactable[mac][0])
				end
			end
		end
		return out
	end
	def getPortByMacAddress(addr)
		@me.send("switch\r")
		wait("#")
		@me.send("show mac include mac #{addr}\r")
		r = self.parseMacAddress('mac')
		@me.send("exit\r")
		wait("#")
		for c in 0..3
			self.getMacAddressOntId(c)
		end
		
		@mactable.each do |mac,v|
			#p mac,v
			v.each do |i|
				if i['port'] =~ /^pon-port ([0-9]+)/
					i['port'] = @ontidtable[mac] 
				end
			end
		end
		#p @mactable
		return r
	end
	def getMacAddressAll()
		@me.send("show mac address-table\n")
		self.parseMacAddress('all')
	end
	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		wait("Mac table")
		@me.each do
			expect(/([0-9]+)\s+([0-9a-f:]+)\s+([A-Za-z0-9\\\/\-]+\s[0-9]+)\s+(Dynamic|Static)\s+\n/) do |x|
				#mac = slf.macToNormal(x[2])
				#vlan = x[1]
				#port = x[3]
				#pinfo "vlan=#{vlan} mac=#{mac} port=#{port}"
				#slf.mactable[mac] = { 'port' => port, :vlan => vlan }			
			
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[2])
				lst['vlan'] = x[1].to_i
				lst['port'] = x[3]
				pinfo lst
				slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
				slf.mactable[lst[groupkey]].push(lst)
			
			end
			expect(/<space>/) do
				pinfo "More"
				send(" ")
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return slf.mactable
	end
	def getMacAddressOntId(port)
		slf = self
		slf.ontidtable = Hash.new if slf.ontidtable == nil
		@me.send("show mac interface gpon-port #{port}\r")
		wait("Serial")
		out = []
		@me.each("more") do
			expect(/\s+[0-9]+\s+[0-9a-zA-Z]+\s+([0-9]+)\s+([0-9]+)\s+[0-9]+\s+([0-9]+)?\s+([0-9]+)?\s+([0-9]+)\s+([:A-F0-9]+)/) do |x|
				#p x
				ponport = x[2]
				ontid = x[1]
				vlan = x[7]
				mac = slf.macToNormal(x[6])
				slf.ontidtable[mac] = "#{ponport}/#{ontid}"
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return out
	end
	def getPONFromClientToHeadSignal(iface)
		signal = nil
		@me.send("show interface ont #{iface} connected\r")	
		#         2    ELTX6204C410         1            0        OK       -28.54    3.24.0.895          NTU-1    Client_Kutuzova_75
		error = false
		@me.each() do 
			expect(/##/) do 
				break
			end
			expect(/Invalid/) do
				error = true
				break
			end
		end
		# error 
		return nil if error
		@me.each("more") do
			expect(/\s+([0-9]+)\s+(ELTX[0-9A-Z]+)\s+([0-9]+)\s+([0-9]+)\s+([A-Za-z]+)\s+([0-9.\-]+)\s+([0-9.]+)\s+([0-9A-Z\-]+)\s+([0-9A-Za-z_\-]+)/) do |x|
				signal = x[6]
				pinfo "Terminal signal from client: #{signal}"
					
			end
			expect(/#/) do
				break
			end
		end
		signal
	end

	def getPONFromHeadToClientSignal(iface)
		signal = nil
		@me.send("show interface ont #{iface} laser\r")	
		#    Rx power:            -20.36 [dBm]*
		@me.each do
			expect(/\s+Rx power:\s+([0-9.\-]+)\s\[dBm\]\*/) do |x|
				signal = x[1]
				pinfo "Terminal signal from head: #{signal}"
					
			end
			expect(/Invalid/) do
				break
			end
			expect(/#/) do
				break
			end
		end
		signal
	end
	def getPONClientPortsError(iface)
		list = Hash.new
		port = '0'
		@me.send("show interface ont #{iface} counters ethernet-performance-monitoring-history-data\r")
		error = false
		@me.each() do 
			expect(/counters/) do 
				break
			end
			expect(/Invalid/) do
				error = true
				break
			end
		end
		# error 
		return nil if error
		@me.each do
			expect(/\s+([0-9#]+)\s+([A-Za-z :]+)\s+([0-9]+) /) do |x|
				key = x[2].strip
				val = x[3]
				list[port] = Hash.new if list[port] == nil
				list[port][key] = val
			end
			expect(/#/) do
				break
			end
		end
		list
	end

	def ConfigurationMode
	end

	def setBroadcastStorm(port,speed)
		slf = self
	end
	def writeCfg
		slf = self
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("copy fs://config tftp://#{host}/#{dest} \r")
	end
	def ping(host)
	end
	def exit()
		@me.send("\r")
		@me.each do
			expect(/#/) do
				send("exit\r")
			end
			expect(/>/) do
				send("exit\r")
				break
			end
		end
		super
	end
end

