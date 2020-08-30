class Qtech28Template < Switch
	
	attr_accessor :collisions

	def templates
		super();
		# set templates
		#
		@me.templates("more") do
			expect(/--More--/) do
				pinfo "More"
				send(" ")
			end
		end
	end

	def getConfiguration
		slf = self
		
		
		# getting config
		#
		@me.send("show running\n")
		@me.each("more") do
			expect(/hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/Interface Ethernet([0-9\/]+)\n/) do |x|
				pinfo "Ethernet #{x[1]}"
				# reset section variables
				slf.curiface = x[1]
				slf.curvlans = Array.new
				slf.curmode = nil
				slf.set_option("ports",slf.curiface,nil,nil)
				
				each("more") do 
					expect(/switchport mode trunk/) do |x|
						pinfo "Trunk #{slf.curiface}"
						slf.curmode = "trunk"
						slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans.push("2-4094")
						slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
					end
					expect(/switchport trunk allowed vlan ([0-9;]+)\n/) do |x|
						pinfo "Trunk allowed #{slf.curiface} vlans #{x[1]}"
						slf.curmode = "trunk"
						slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans = x[1].split(";")
						slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
					end
					expect(/switchport access vlan ([0-9]+)\n/) do |x|
						pinfo "Access #{slf.curiface} vlan #{x[1]}"
						slf.curmode = "access"
						slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans.push(x[1])
						slf.set_option("ports",slf.curiface,"untagged",slf.curvlans)
					end
					expect(/description (.*?)\n/) do |x|
						desc = x[1].delete('"')
						pinfo "Description #{desc}"
						slf.set_option("ports",slf.curiface,"desc",desc)
					end
					expect(/!/) do
						pinfo "End of section"
						break
					end
				end
			end
			expect(/^vlan ([0-9]+)/) do |x|
				pinfo "Vlan #{x[1]}"
				slf.curiface = x[1].to_i
				slf.set_option("vlans",slf.curiface,nil,nil)
				each("more") do
					expect(/name (.*?)\n/) do |x|
						pinfo "Vlan name is #{x[1]}"
						slf.set_option("vlans",slf.curiface,"name",x[1].delete('"'))	
					end
					expect(/!/) do
						pinfo "End of section"
						break
					end
				end
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end
		end
		
		self.setUnconfiguredAccess()
	end

	def ConfigurationMode
		@me.send("conf t\n")
		self.wait(/\(config\)#/)
		yield
		@me.send("exit\n")
		self.wait(/#/)
	end
	def getPortsStatus()
		slf = self
		@me.send("show int e s\n")
		# wait start command
		wait("Interface  Link/Protocol  Speed")
		@me.each("more") do
			#1/25       UP/UP          a-1G    a-FULL  trunk  G-Combo:Copper  N-L3-Cisco3750
			expect(/([0-9\/]+)\s+([A-Z\-\/]+)\s+([a-zA-Z0-9\-\/\\:_]+)\s+([a-zA-Z0-9\-\/\\:_]+)\s+([a-zA-Z0-9\-\/\\:_]+)\s+([a-zA-Z0-9\-\/\\:_]+)\s+([a-zA-Z0-9\-\/\\:_]+)?\n/) do |x|
				if x[2] == "DOWN/DOWN" 
					state = "DOWN"
				elsif x[2] == "A-DOWN/DOWN"
					state = "A-DOWN"
				else
					state = "UP"
				end
				if x[3] =~ /100M/
					speed = 100
				elsif x[3] =~ /1G/
					speed = 1000
				elsif x[3] =~ /10G/
					speed = 10000
				else
					speed = 0
				end
				
				pinfo "Port: #{x[1]} state #{state} speed #{speed}"
				slf.set_option("ports","#{x[1]}","status",state)
				slf.set_option("ports","#{x[1]}","speed",speed)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end
		end
		self.list['ports']
	end
	def getPortError(port)
		port = port.gsub(/Ethernet/,'')
		slf = self
		@me.send("show int e #{port}\n")
		@me.each("more") do
			expect(/([0-9]+) input packets, ([0-9]+) bytes/) do |x|
				pinfo "rx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"rx_bytes",x[2].to_i)
			end
			expect(/([0-9]+) output packets, ([0-9]+) bytes/) do |x|
				pinfo "tx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"tx_bytes",x[2].to_i)
			end

			#0 input errors, 0 CRC, 0 frame alignment, 0 overrun, 0 ignored
			expect(/([0-9]+) input errors, ([0-9]+) CRC, ([0-9]+) frame alignment, ([0-9]+) overrun, ([0-9]+) ignored,/) do |x|
				slf.set_option("ports",port,"rx_errors",x[1].to_i)
				slf.set_option("ports",port,"rx_crc_error",x[2].to_i)
				slf.set_option("ports",port,"rx_frame_aligment",x[3].to_i)
				slf.set_option("ports",port,"rx_overrun",x[4].to_i)
				slf.set_option("ports",port,"rx_ignore",x[5].to_i)
			end
			#0 abort, 0 length error, 0 undersize 0 jabber, 0 fragments, 0 pause frame
			expect(/([0-9]+) abort, ([0-9]+) length error, ([0-9]+) undersize ([0-9]+) jabber, ([0-9]+) fragments, ([0-9]+) pause frame/) do |x|
				slf.set_option("ports",port,"rx_abort",x[1].to_i)
				slf.set_option("ports",port,"rx_length_error",x[2].to_i)
				slf.set_option("ports",port,"rx_undersize",x[3].to_i)
				slf.set_option("ports",port,"rx_jabber",x[4].to_i)
				slf.set_option("ports",port,"rx_fragments",x[5].to_i)
				slf.set_option("ports",port,"rx_pause_frame",x[6].to_i)
			end
			#0 output errors, 0 collisions, 0 late collisions, 0 pause frame
			expect(/([0-9]+) output errors, ([0-9]+) collisions, ([0-9]+) late collisions, ([0-9]+) pause frame/) do |x|
				slf.set_option("ports",port,"tx_error",x[1].to_i)
				slf.set_option("ports",port,"tx_collisions",x[2].to_i)
				slf.set_option("ports",port,"tx_late_collisions",x[3].to_i)
				slf.set_option("ports",port,"tx_pause_frame",x[4].to_i)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end
		end
		self.list['ports'][port]
	end
	def clearPortCounter(port)
		@me.send("clear counters interface ethernet #{port}\n")
		wait("#")
	end
	def setPortState(port,state)
		newstate = ( state ) ? "no shutdown\n" : "shutdown\n";
		@me.send("interface ethernet #{port}\n")
		wait("#")
		@me.send(newstate)
		wait("#")
		@me.send("exit\n")
		wait("#")
	end
	def getMacAddressByVlan(vlan)
		@me.send("show mac-address-table vlan #{vlan}\n")
		self.parseMacAddress('vlan')
	end
	def getMacAddressByPort(port)
		@me.send("show mac-address-table interface e #{port}\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show mac-address-table\n")
		self.parseMacAddress('all')
	end
	
	def getPortByMacAddress(addr)
		@me.send("show mac-address-table address #{addr}\n")
		self.parseMacAddress('mac')
	end
	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		@me.each do
			expect(/^([0-9]+)\s+([0-9a-f:.-]+)\s+(DYNAMIC|STATIC)\s+(?:Hardware|User)\s+Ethernet([0-9\\\/]+)\n/) do |x|
				#mac = slf.macToNormal(x[2])
				#vlan = x[1]
				#port = x[4]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = { :port => port, :vlan => vlan }			
				
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[2])
				lst['vlan'] = x[1].to_i
				lst['port'] = x[4]
				pinfo lst
				slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
				slf.mactable[lst[groupkey]].push(lst)
			end
			expect(/--More--/) do
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


	def setBroadcastStorm(port,speed)
		slf = self
		@me.send("interface #{port}\n")
		@me.send("storm-control broadcast #{speed}\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
	def writeCfg
		slf = self
		@me.send("copy running-config startup-config\n")
		slf.wait("[Y/N]")
		@me.send("y\n")
		wait("successful")
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("copy running-config tftp://#{host}#{dest}\n")
		slf.wait("[Y/N]")
		@me.send("y\n")
		wait("File transfer complete.")
		wait("#")
	end
	def ping(host)
		@me.send("traceroute #{host} timeout 100 hop 3\\nn")	
		wait("#")
	end
	

	def exit()
		@me.send("exit\n")
		super
	end

	##########################################################################
	# garbage
	##########################################################################

	def setSnmpTrapHost(host,community)
		@me.send("snmp-server host #{host} v2c #{community}")	
		wait("#")
	end
	def removeSnmpTrapHost(host,community)
		@me.send("no snmp-server host #{host} v2c #{community}")
		wait("#")
	end
	#
	# collisions
	#
	def getCollisions()
		slf = self
		slf.collisions = Hash.new
		@me.send("show collision-mac-address-table\n")
		@me.each do
			expect(/^[*|\s]{1}([0-9a-f.-]+)\s+([0-9]+)\s+([0-9]+)\n/) do |x|
				mac = slf.macToNormal(x[1])
				vlan = x[2]
				count = x[3]
				pinfo " mac #{mac} vlan = #{vlan} count = #{count}"
				slf.collisions[mac] = { :vlan => vlan, :count => count }			
			end
			expect(/--More--/) do
				pinfo "More"
				send(" ")
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return slf.collisions
	end

	def clearCollisions()
		slf = self
		@me.send("clear collision-mac-address-table\n")
		self.wait("#")
	end
	def avoidCollisions()
		slf = self
		@me.send("mac-address-table avoid-collision\n")
		self.wait("#")
	end
	def noAvoidCollisions()
		slf = self
		@me.send("no mac-address-table avoid-collision\n")
		self.wait("#")
	end
	def disableHttp()
		@me.send("no ip http server\n")
		wait("#")
	end
	
	def disableHttps()
		@me.send("no ip http secure-server\n")
		wait("#")
	end
end



