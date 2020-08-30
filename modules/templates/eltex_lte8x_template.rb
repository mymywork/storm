class  EltexLte8xTemplate < Switch

	attr_accessor :list_ponports
	attr_accessor :list_ontid
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
		@broadcastLimitAccess = 32
		@broadcastLimitTrunk = 900
		@ifacenames = { 
		}
		@ontid = Hash.new
		@list_ponports = nil
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
		#if x = port.match(/[a-z]+[0-9]+\/[0-9]+\/([0-9]+)/)
		#	return x[1]
		#end
		port
	end

	def getConfiguration
		slf = self
		slf.set_option("global","hostname",nil, "ltp8x")
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
		for c in 0..7
			self.getMacAddressOntId(c)
		end

		@mactable.each do |mac,v|
			#p mac,v
			v.each do |i|
				if i['port'] =~ /^pon-port ([0-9]+)/
					# rewrite port on x/x
					i['port'] = @list_ontid[mac] 
				end
			end
		end
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
		for c in 0..7
			self.getMacAddressOntId(c)
		end

		outtmp = Hash.new
		out = Hash.new
		@list_ontid.each do |mac,v|
			#p mac,v
			if v == port
				if @mactable.has_key?(mac)
					out[v] = Array.new if out[v] == nil 
					out[v].push(@mactable[mac][0])
				end
			end
		end
		#p outtmp
 
		return out
	end
	
	def getPortByMacAddress(addr)
		@me.send("switch\r")
		wait("#")
		@me.send("show mac include mac #{addr}\r")
		r = self.parseMacAddress('mac')
		@me.send("exit\r")
		wait("#")
		for c in 0..7
			self.getMacAddressOntId(c)
		end
		#p @list_ontid
		@mactable.each do |mac,v|
			#p mac,v
			v.each do |i|
				if i['port'] =~ /^pon-port ([0-9]+)/
					pdbg "CONGRAT !"
					# rewrite port on ont/id
					i['port'] = @list_ontid[mac] 
				end
			end
		end
		#p r
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
		@me.each("more") do
			expect(/([0-9]+)\s+([0-9a-f:]+)\s+([A-Za-z0-9\-]+\s[0-9]+?)\s+(Dynamic|Static)/) do |x|
				#p x
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
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return slf.mactable
	end
	
	def getMacAddressOntId(port)
		slf = self
		slf.list_ontid = Hash.new if slf.list_ontid == nil
		@me.send("show mac table #{port}\r")
		wait("MAC table")
		out = []
		curid = nil
		@me.each do
			expect(/\s[0-9]+\) CONFIG Ch\/ID: [x0-9]+\/[0-9]+\s+STATUS Ch\/ID: ([0-9\/]+) /) do |x|
				#p x
				curid = x[1]
			end
			expect(/\+[0-9]+\) ([0-9A-F:]+)/) do |x|
				#p x
				mac = slf.macToNormal(x[1])
				slf.list_ontid[mac] = curid
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return out
	end

	#         193  x/1139         4/1139         02:00:5E:02:8F:40  NTE-2:B+                    2.60  OK                3.0 uW (-25.2 dBm)       4
	#	  194  x/1119         2/1119         02:00:57:00:00:7C  NTE-RG-1402GC-W:rev.B      E1.17  OK                4.9 uW (-23.1 dBm)       4
	def igetListPonPortsInfo
		slf = self
		signal = ""
		return @list_ponports if @list_ponports != nil 
		@list_ponports = Hash.new
		@me.send("show ont list verbose all\r")
		wait("CONFIG")
		@me.each("more") do
			#expect(/\s+([0-9]+)\s+x\/([0-9]+)\s+([0-9\/]+)\s+([0-9A-F:]+)\s+([0-9A-Za-z\-:.+])\s+([A-Za-z0-9.]+)\s+([A-Z]+)\s+([0-9.]+)\s+uW\s+\(([0-9.\-]) dBm\)\s+([0-9]+)\n/) do |x|
			expect(/\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+uW\s+\((.*?) dBm\)\s+(.*?)/) do |x|
				signal = x[9]
				mac = x[4]
				model = x[5]
				port = x[3]
				version = x[6]
				slf.list_ponports[port] = { :mac => mac, :signal => signal, :model => model, :version => version }
				pinfo "Signal from client #{x[9]}"
			end
			expect(/#/) do
				break
			end
		end
		
	end
	def getPONFromClientToHeadSignal(iface)
		igetListPonPortsInfo()
		if @list_ponports.has_key?(iface)
			return @list_ponports[iface][:signal]
		else
			return nil
		end
	end
	def getPONFromHeadToClientSignal(iface)
		signal = "Not supported"
		signal
	end
	def getPONClientPortsError(iface)
		list = Hash.new
		if @list_ponports.has_key?(iface)
			mac = @list_ponports[iface][:mac]
			@me.send("ont_mac #{mac}\r")
			wait("#")
			@me.send("stat pon receive\r")
			catchData('pon',list)
			@me.send("stat uni0 receive\r")
			catchData('uni0',list)
			@me.send("stat uni1 receive\r")
			catchData('uni1',list)
			@me.send("exit\r")
			return list
		else
			return nil
		end
	end
	def catchData(port,list)
		@me.each do
			expect(/(.*?) = ([0-9]+)/) do |x|
				key = x[1]
				val = x[2]
				list[port] = Hash.new if list[port] == nil
				list[port][key] = val
				pinfo "#{x[1]} = #{x[2]}"
			end
			expect(/#/) do
				break
			end
		end
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
		@me.send("upload config backup #{dest} #{host}\r")
	end
	def ping(host)
	end
	def exit()
		wait("#")
		@me.send("logout\r")
		super
	end
end

