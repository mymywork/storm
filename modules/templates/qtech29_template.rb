class Qtech29Template < Switch

	def protocols
	end

	def templates
		
		@me.templates("more") do 
			expect(/ENTER/) do
				pinfo "More"
				send(" ")
			end
		end
	end


	def getConfiguration
		slf = self

		#
		# templates
		#
		@me.templates("ifaceopts") do
			expect(/description (.*?)\n/) do |x|
				desc = x[1].delete('"')
				pinfo "Description #{desc}"
				slf.set_option("ports",slf.curiface,"desc",desc)
			end
			expect(/switchport mode access/) do |x|
				pinfo "Access #{slf.curiface}"
				slf.curmode = "access"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
			end
			expect(/switchport mode trunk/) do |x|
				pinfo "Trunk #{slf.curiface}"
				slf.curmode = "trunk"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
			end
			expect(/^switchport trunk allowed vlan ([0-9,-]+)\n/) do |x|
				pinfo "Trunk #{slf.curiface} vlans #{x[1]}"
				slf.curmode = "trunk"
				slf.curvlans = x[1].split(",")
				pinfo "Trunk has #{slf.curvlans}"
				slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
			end
			expect(/switchport default vlan ([0-9]+)\n/) do |x|
				pinfo "Access #{slf.curiface}"
				slf.curmode = "access"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
				slf.curvlans.push(x[1])
				slf.set_option("ports",slf.curiface,"untagged",slf.curvlans)
			end
			expect(/exit/) do
				pinfo "End of section"
				break
			end
			expect(/ENTER/) do
				pinfo "More"
				send(" ")
			end
		end

		#
		# show config
		#
		@me.send("show running\n")
		#
		# each include child ifacerange expect code
		#
		@me.each("ifacerange") do
			expect(/hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/interface ethernet ([0-9\/]+)\n/) do |x|
				# reset section variables
				slf.curiface = nil
				slf.curvlans = Array.new
				slf.curmode = nil
				#
				pinfo "Ethernet #{x[1]}"
				slf.curiface = x[1]
				slf.set_option("ports",slf.curiface,nil,nil)
				each("ifaceopts")
			end
			expect(/^vlan ([0-9]+)/) do |x|
				pinfo "Vlan #{x[1]}"
				slf.curiface = x[1].to_i
				slf.set_option("vlans",slf.curiface,nil,nil)
				each do
					expect(/description (.*?)\n/) do |x|
						desc = x[1].delete('"')
						slf.set_option("vlans",slf.curiface,"name",desc)
					end
					expect(/ENTER/) do
						pinfo "More"
						send(" ")
					end
					expect(/exit/) do
						pinfo "End of section"
						break
					end
				end
			end
			expect(/ENTER/) do
				pinfo "More"
				send(" ")
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end

		self.setUnconfiguredAccess()
		
	end
	def enableMode()
		slf = self
		@me.send("\n")
		@me.each do
			expect(/>/) do
				pinfo "Detected unprivileged prompt"
				send("en\n")
			end
			expect(/assword:/) do
				pinfo "Send password"
				send("#{slf.enablePassword}\n")
			end
			expect(/#/) do
				pinfo "Detected privileged prompt"
				break
			end
		end
	end
	def getPortsStatus()
		slf = self
		@me.send("show int br\n")
		# wait start
		wait("Port    Desc   Link shutdn Speed")
		@me.each do
			#e0/1    S-Adm_ up   false  auto-f100     0   56   hyb                                      56,1001\n"
			#e0/4    S-OZPP down false  auto          0   56   hyb                                      56,1001
			#e0/19   S-LenA up   false  auto-f100     0   267  acc                                      267
			expect(/e([0-9\/]+)\s+.*?\s+(up|down)\s+(false|true)\s+([0-9a-zA-Z\-]+)/) do |x|
				if x[2] == "down" 
					state = "DOWN"
				else
					state = "UP"
				end
				if x[4] =~ /10000$/
					speed = 10000
				elsif x[4] =~ /1000$/
					speed = 1000
				elsif x[4] =~ /100$/
					speed = 100
				else
					speed = 0
				end

				pwarn x
				pinfo "Port: #{x[1]} state #{state} speed #{speed}"
				slf.set_option("ports",x[1],"status",state)
				slf.set_option("ports",x[1],"speed",speed)
			end
			expect(/ENTER/) do
				pinfo "More"
				send(" ")
			end
			expect(/#/) do
				pinfo "Detected Prompt - getPortStatus"
				break
			end
		end

		pinfo "Detected Prompt 2 - getPortStatus"
		wait("#")
		self.list['ports']
	end
	def getPortError(port)
		slf = self
		@me.send("sh statistics int e #{port}\n")
		@me.each("more") do
			expect(/([0-9]+) packets input, ([0-9]+) bytes/) do |x|
				pinfo "rx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"rx_bytes",x[2].to_i)
			end
			expect(/([0-9]+) packets output, ([0-9]+) bytes/) do |x|
				pinfo "tx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"tx_bytes",x[2].to_i)
			end

			expect(/([0-9]+) input errors, ([0-9]+) FCS error/) do |x|
				pinfo "#{x[1]} input errors, #{x[2]} FCS error"
				slf.set_option("ports",port,"rx_errors",x[1].to_i)
				slf.set_option("ports",port,"rx_crc_error",x[2].to_i)
			end
			expect(/([0-9]+) runts, ([0-9]+) giants/) do |x|
				pinfo "#{x[1]} runts, #{x[2]} giants"
				slf.set_option("ports",port,"rx_runts",x[1].to_i)
				slf.set_option("ports",port,"rx_giants",x[2].to_i)
			end
			expect(/([0-9]+) output errors, ([0-9]+) deferred, ([0-9]+) collisions/) do |x|
				pinfo "#{x[1]} output errors, #{x[2]} deferred, #{x[3]} collisions"
				slf.set_option("ports",port,"tx_errors",x[1].to_i)
				slf.set_option("ports",port,"tx_deferred",x[2].to_i)
				slf.set_option("ports",port,"tx_collisions",x[3].to_i)
			end
			expect(/([0-9]+) late collisions/) do |x|
				pinfo "#{x[1]} late collisions"
				slf.set_option("ports",port,"tx_late_collisions",x[1].to_i)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end

		end
		self.list['ports'][port]
	end
	def clearPortCounter(port)
		@me.send("conf t\n")
		wait("config")
		@me.send("clear interface ethernet #{port}\n")
		wait("successfully.")
		@me.send("exit\n")
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
		@me.send("show mac-address-table interface ethernet #{port}\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show mac-address-table\n")
		self.parseMacAddress('all')
	end
	def getPortByMacAddress(addr)
		@me.send("show mac-address-table #{addr}\n")
		self.parseMacAddress('mac')
	end
	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		@me.each do
			expect(/([0-9a-f.:-]+)\s+([0-9]+)\s+([A-Za-z0-9\\\/]+)\s+(dynamic|static)\s+?(active)?/) do |x|
				#mac = slf.macToNormal(x[1])
				#vlan = x[2]
				#port = x[3]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = { :port => port, :vlan => vlan }			
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[1])
				lst['vlan'] = x[2].to_i
				lst['port'] = x[3]
				pinfo lst
				slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
				slf.mactable[lst[groupkey]].push(lst)
			end
			expect(/ENTER/) do
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

	def ConfigurationMode
		@me.send("conf t\n")
		self.wait(/\(config\)#/)
		yield
		@me.send("exit\n")
		self.wait(/#/)
	end
	def setBroadcastStormEnable(speed)
		slf = self
		if !@broadcast_enable
			@me.send("storm-control ratio #{speed}\n")
			@me.send("storm-control type broadcast\n")
			self.wait(/\(config/)
			@broadcast_enable=true
		end
	end
	def setBroadcastStorm(port,speed)
		slf = self
		self.setBroadcastStormEnable(speed)
		@me.send("int e #{port}\n")
		@me.send("storm-control\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
	def writeCfg
		slf = self
		@me.send("copy running-config startup-config\n")
		wait("(y/n)")
		@me.send("y")
		wait("successful")
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("upload configuration tftp #{host} #{dest}\n")
		slf.wait("Upload config file via TFTP successfully.")
	end
	def ping(host)
		@me.send("ping -t 1 -n 1 #{host}\n")	
		wait("#")
	end
	def setSnmpTrapHost(host,community)
		@me.send("snmp-server host #{host} version 2c #{community} udp-port 162 notify-type bridge gbn gbnsavecfg interfaces rmon snmp")	
		wait("#")
	end
	def removeSnmpTrapHost(host,community)
		@me.send("no snmp-server host #{host} #{community} 2c\n")
		wait("#")
	end
	def setLogging(host)
		@me.send("logging #{host}\n")
		wait("#")
		@me.send("logging host #{host} level-list 0 3 module lldp\n")
		wait("#")
	end
	def checkPingPong
		@me.send("show version\n")	
		wait("QTECH")
		if @me.timeout == true
			return false
		end
		wait("#")
		return true
	end
	def disableHttp()
		@me.send("http disable\n")
		wait("#")
	end
	
	def disableHttps()
	end

	def exit()
		@me.send("\n")
		@me.each do
			expect(/#/) do
					send("exit\n")
				end
				expect(/>/) do
					send("exit\n")
				break
			end
		end
		super
	end
end

