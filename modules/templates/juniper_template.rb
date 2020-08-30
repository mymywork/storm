
class JuniperTemplate < Switch

	attr_accessor :flagcmd
	attr_accessor :vlans

	def initialize(mexp)
		super(mexp)
		@me = mexp
		@trunknames = [ ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
		@vlans = nil

		@db = Db.new
	end
	
	def templates()
		#
		# set templates
		#
		@me.templates("more") do
			expect(/---\(more([\s0-9%]+)?\)---/) do
				pinfo "More"
				send(" ")
			end
		end

	end

	def getAbsolutePort(port)
		if x = port.match(/.e-0\/0\/([0-9]+)/)
			return x[1]
		end
		if x = port.match(/[a-z]{2}([0-9]+)/)
			return x[1]
		end
		return port
	end
	def getPortsStatus()
		slf = self
		@me.send("show interfaces desc\n")
		@me.each do
			#xe-0/0/24       up    up   S-Domashnie_Seti-Sovetskaya_10d1
			expect(/^([a-z0-9\-\/\.]+)\s+([A-Za-z]+)\s+([A-Za-z]+)\s+([A-Za-z0-9\-\_\.\\\/]+)\n/) do |x|
				if x[3] == "down" 
					state = "DOWN"
				else
					state = "UP"
				end
				if x[2] == "down" 
					state = "A-DOWN"
				end
				pinfo "Port: #{x[1]} state #{state}"
				slf.set_option("ports",x[1],"status",state)
			end
			expect(/\(more\)/) do
				pinfo "Detected more"
				send(" ")
			end
			expect(/>/) do
				pinfo "Detected Prompt"
				break
			end
		end
		self.list['ports']
	end
	def getConfiguration
	
		slf = self
		level = Array.new
		#
		# interface
		#
		@me.templates("iface") do
			expect(/\s{8}description (.*?);/) do |x|
				desc = x[1].delete('"')
				pinfo "Description #{desc}"
				slf.set_option("ports",slf.curiface,"desc",desc)
			end
			# unit 0 {
			expect(/\s{8}unit ([0-9]+) {/) do |x|
				# set ports + unit
				each("more") do
					# family ethernet-switching {
					expect(/\s{12}family ethernet-switching/) do 
						each("more") do
							expect (/\s{16}port-mode trunk/) do
								pinfo "Port mode trunk"
								slf.curmode = "trunk"
								slf.set_option("ports",slf.curiface,"mode",slf.curmode)
							end
							# exit from family ether-switching
							expect(/^\s{12}\}/) do 
								break	
							end
						end
					end
					# exit from unit
					expect(/^\s{8}\}/) do 
						break	
					end
				end
			end
			# exit from section interface
			expect(/^\s{4}\}/) do 
				break	
			end
		end
		#
		# getting config
		#
		@me.send("show configuration\n")
		@me.each("more") do
			expect(/system \{/) do |x|
				each("more") do 
					expect(/host-name (.*?);\n/) do |x|
						pinfo "Hostname: #{x[1]}"
						slf.set_option("global","hostname",nil, x[1].delete('"'))
					end
					expect(/^}/) do 
						break	
					end
				end
			end
			expect(/^interfaces \{/) do |x|
				slf.curvlans = Array.new
				slf.curmode = nil
				each("more") do 
					expect(/^\s{4}interface-range (.*?) {/) do |x|
						pinfo "Interface: #{x[1]}"
						slf.curiface = x[1]
						#slf.set_option("ports",slf.curiface,nil,nil)
						#each("iface","more")
					end
					expect(/^\s{4}([A-Za-z0-9_\\\/.-]+) {/) do |x|
						pinfo "Interface: #{x[1]}"
						slf.curiface = x[1]
						slf.set_option("ports",slf.curiface,nil,nil)
						each("iface","more")
					end
					expect(/^\}/) do
						break
					end
				end
			end
			# vlans {
			expect(/^vlans \{/) do
				pinfo "Entering into vlans"
				each("more") do
					# vlan_name {
					expect(/^\s{4}(.*?) {/) do |x|
						pinfo "Vlan name = #{x[1]}"
						desc = x[1]
						each("more") do
							# vlan-id
							expect(/vlan-id ([0-9]+);/) do |x|
								pinfo "Vlan tag = #{x[1].to_i}"
								slf.set_option("vlans",x[1].to_i,"name",desc)
							end
							expect(/^\s{4}\}/) do
								break
							end
						end
					end
					expect(/^\}/) do
						break
					end
				end
			end
			# master exit
			expect(/{master:0}/) do
				pdbg "exit from config"
				break
			end
		end
		self.setUnconfiguredAccess()
	end

	def getPortError(port)
		slf = self
		@me.send("show interfaces #{port} extensive\n")
		#wait("Physical interface")
		@me.each("more") do
		
			expect(/Physical interface/) do 
			end
			
			expect(/error: device/) do
				pinfo "Device not found"
				break
			end

			expect(/Traffic statistics/) do
				pinfo "Traffic statistic"
				each("more") do
					expect(/Input\s+bytes\s+:\s+([0-9]+)/) do |x|
						pinfo "rx_bytes=#{x[1]}"	
						slf.set_option("ports",port,"rx_bytes",x[1].to_i)
					end
					expect(/Output\s+bytes\s+:\s+([0-9]+)/) do |x|
						pinfo "tx_bytes=#{x[1]}"	
						slf.set_option("ports",port,"tx_bytes",x[1].to_i)
						break
					end
				end
			end

			expect(/Input errors:/) do 
				each("more") do
					expect(/Errors: ([0-9]+)/) do |x|
						slf.set_option("ports",port,"rx_errors",x[1].to_i)
						break
					end
				end
			end

			expect(/Output errors:/) do 
				each("more") do
					expect(/Errors: ([0-9]+)/) do |x|
						slf.set_option("ports",port,"tx_error",x[1].to_i)
						break
					end
				end
			end
		
			expect(/>/) do
				pinfo "Prompt detected"
				break
			end
		end
		self.list['ports'][port]
	end

	def getArpTable(invlan=nil)
		if invlan == nil
			@me.send("show arp\n")
		else
			@me.send("show arp interface #{invlan}\n")
		end
		table = Hash.new
		@me.each("more") do 
			expect(/([a-f0-9:]+)\s+([0-9.]+)\s+([A-Za-z0-9\-_.]+)\s+([a-z0-9\/\-\.]+)\s+(.*?)/) do |x|
				mac = x[1]
				host = x[2]
				vlan = x[4]
				pinfo "Host: #{host} has mac #{mac} vlan #{vlan}"
				table[host] = { "mac" => mac, "vlan" => vlan }
			end
			expect(/>/) do
				pinfo "Detected prompt"
				break
			end
		end
		return table
	end

	def arpResolve(host)
		mac = nil
		@me.send("show arp hostname #{host}\n")

		@me.each do 
			expect(/([a-f0-9:]+)\s+([0-9.]+)\s+([A-Za-z0-9\-_.]+)\s+([a-z0-9\/\-\.]+)\s+(.*?)/) do |x|
				mac = x[1]
				port = x[4]
				pinfo "Host: #{host} has mac #{mac}"
			end
			expect(/>/) do
				pinfo "Detected prompt"
				break
			end
		end
		return mac	
	end

	def getMacAddressByVlan(vlan)
		@me.send("show ethernet-switching table vlan #{vlan}\n")
		self.parseMacAddress('vlan',vlan)
	end
	def getMacAddressByPort(port)
		@me.send("show ethernet-switching table | match \"#{port}|Ethernet\"\n")
		self.parseMacAddress('port')
	end
	def getPortByMacAddress(addr)
		@me.send("show ethernet-switching table | match \"#{addr}|Ethernet\"\n")
		self.parseMacAddress('mac')
	end
	def getMacAddressAll
		@me.send("show ethernet-switching table\n")
		self.parseMacAddress('all')
	end

	def parseMacAddress(groupkey,value=nil)
		#wait("master")
		slf = self
		slf.mactable = Hash.new
		flagcmd = false
		@me.each do
			expect(/\s+([0-9A-Za-z_-]+)\s+([0-9.:a-f]+)\s+(Learn|Static)\s+[0-9:]+\s+([A-Za-z0-9\\\/-]+)\./) do |x|
				#mac = slf.macToNormal(x[2])
				#vlan = x[1]
				#port = x[4]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = { :port => port, :vlan_name => vlan }			
				
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[2])
				lst['vlan'] = value
				lst['vlan_name'] = x[1]
				lst['port'] = x[4]
				pinfo lst
				slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
				slf.mactable[lst[groupkey]].push(lst)
			end
			expect(/more/) do
				pinfo "More"
				send("\s")
			end
			expect(/Ethernet-switching/) do
				pinfo "Detected start of cmd."
				flagcmd = true
				pinfo "Master is #{flagcmd}"
			end
			expect(/>/) do |x|
				pinfo "Master is #{flagcmd}"
				if flagcmd
					pinfo "Detected prompt"
					break
				end
			end
		end
		slf.mactable.each do |mac,list|
			list.each do |item|
				x = getVlanByName(item['vlan_name'])
				if x != nil
					item['vlan'] = x.to_i
				elsif item['vlan_name'] == 'default'
					item['vlan'] = 1
				else
					item['vlan'] = nil
				end
			end
		end
		return slf.mactable
	end

	def getVlanByName(vlan_name)
		@vlans = getVlans() if @vlans == nil
		if @vlans.has_key?(vlan_name)
			return @vlans[vlan_name]
		end
		return nil
	end

	def getVlans
		slf = self
		@me.send("show vlan brief\n")
		vlans = Hash.new
		flagcmd = false
		@me.each do
			expect(/^([0-9A-Za-z_-]+)\s+([0-9]+)\s+/) do |x|
				vlan = x[1]
				tag = x[2]
				pinfo "vlan #{vlan} tag #{tag}"
				vlans[vlan] = tag			
			end
			expect(/more/) do
				pinfo "More"
				send("\s")
			end
			expect(/Primary Address/) do
				pinfo "Detected start of cmd."
				flagcmd = true
				pinfo "Master is #{flagcmd}"
			end
			expect(/>/) do |x|
				pinfo "(getVlans) Master is #{flagcmd}"
				if flagcmd
					pinfo "(getVlans) Detected prompt"
					break
				end
			end
		end
		return vlans
	end

	def enableMode()
		#pinfo "Send crlf for recognize prompt."
		#@me.send("\n")
		#wait(/%/)
		#pinfo "Detected juniper shell."
		#@me.send("cli\n")
		#wait(/>/) 
		#pinfo "Detected juniper cli."
	end
	def ConfigurationMode
	end
	def setBroadcastStorm(port,speed)
	end
	def writeCfg
	end
	def copyCfgToSSH(host,dest)
		slf = self
		@me.send("file copy /config/juniper.conf.gz scp://root@#{host}#{dest}.gz\n")
		@me.each do 
			expect(/password:/) do
				send("#{$backupSSHAccount['password']}\n")
			end
		end
		wait(">")
	end
	def checkPingPong
		@me.send("show version\n")	
		wait("JUNOS")
		if @me.timeout == true
			return false
		end
		return true
	end
	def ping(host)
		@me.send("ping #{host} count 1 wait 1 ")	
		wait(">")
	end
	def exit()
		slf = self
		@me.send("exit\n")
		slf.wait("%")
		@me.send("exit\n")
		super
	end
end

