class CiscoTemplate < Switch

	def initialize(mexp)
		super(mexp)
		@ifacenames = { 
			'FastEthernet' => 'Fa',
			'GigabitEthernet' => 'Gi',
			'Port-channel' => 'Po'
		}
	end
	
	def templates()
		super()	
		@me.templates("more") do
			expect(/--More--/) do
				pinfo "More"
				send(" ")
			end
		end
		# templates	
		@me.templates("section") do
			expect(/^!/) do
				pinfo "End section"
				break
			end
		end
	end
	def getAbsolutePort(port)
		if x = port.match(/Fa0\/([0-9]+)/)
			return x[1]
		end
		#if x = port.match(/Gi[0-9]+\/([0-9]+)$/)
		#	return x[1]
		#end
		if x = port.match(/Gi[0-9]+\/[0-9]+\/([0-9]+)$/)
			return x[1]
		end
		return port
	end
	def getConfiguration
		slf = self
		# config
		@me.send("show running\n")
		@me.each("more") do
			expect(/^hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/interface (Port-channel|GigabitEthernet|FastEthernet)([0-9\/]+)\n/) do |x|
				pinfo "#{x[1]} - #{x[2]}"
				# reset section variables
				slf.curiface = "#{slf.typeLongToShort(x[1])}#{x[2]}"
				slf.curvlans = Array.new
				slf.curmode = nil
				slf.set_option("ports",slf.curiface,nil,nil)
				each("more","section") do
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
						slf.curvlans.push("2-4094")
						slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
					end
					expect(/switchport trunk allowed vlan ([0-9,-]+)\n/) do |x|
						pinfo "Trunk allowed #{slf.curiface} vlans #{x[1]}"
						#slf.curmode = "trunk"
						#slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans = x[1].split(",")
						slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
					end
					expect(/switchport access vlan ([0-9]+)\n/) do |x|
						pinfo "Access #{slf.curiface} vlan #{x[1]}"
						#slf.curmode = "access"
						#slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans.push(x[1])
						slf.set_option("ports",slf.curiface,"untagged",slf.curvlans)
					end
				end	
			end
			expect(/^interface Vlan([0-9]+)\n/) do |x|
				pinfo "Vlan #{x[1]}"
				slf.curiface = x[1].to_i
				slf.set_option("vlans",slf.curiface,nil,nil)
				each("more","section") do
					expect(/description (.*?)\n/) do |x|
						pinfo "Vlan name is #{x[1]}"
						slf.set_option("vlans",slf.curiface,"name",x[1].delete('"'))						
					end
				end
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		
		self.setUnconfiguredAccess()
	end

	def portToShort(port)
		port[0..1]
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
		@me.send("show interfaces status\n")
		@me.each("more") do
			#Gi1/0/4   Gagar connected    trunk      a-full a-1000 1000BaseLX SFP
			expect(/([A-Za-z0-9\/]+)[\s+0-9A-Za-z\-\/_]+\s+(connected|notconnect|disabled)\s+([a-zA-Z0-9\-\:]+)\s+([a-zA-Z0-9\-\:]+)\s+([a-zA-Z0-9\-\:]+)/) do |x|
				if x[2] == "notconnect" || x[2] == "disabled" 
					state = "DOWN"
				else
					state = "UP"
				end

				if x[5] =~ /10000$/
					speed = 10000
				elsif x[5] =~ /1000$/
					speed = 1000
				elsif x[5] =~ /100$/
					speed = 100
				else
					speed = 0
				end
				
				pinfo "Port: #{x[1]} state #{state} speed #{speed}"
				slf.set_option("ports",x[1],"status",state)
				slf.set_option("ports",x[1],"speed",speed)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end
		end
		self.list['ports']
	end
	def getPortError(port)
		slf = self
		@me.send("show int #{port}\n")
		@me.each("more") do
			expect(/([0-9]+) packets input, ([0-9]+) bytes/) do |x|
				pinfo "rx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"rx_bytes",x[2].to_i)
			end
			expect(/([0-9]+) packets output, ([0-9]+) bytes/) do |x|
				pinfo "tx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"tx_bytes",x[2].to_i)
			end

			expect(/([0-9]+) input errors, ([0-9]+) CRC, ([0-9]+) frame, ([0-9]+) overrun, ([0-9]+) ignored/) do |x|
				pinfo "#{x[1]} input errors, #{x[2]} CRC, #{x[3]} frame, #{x[4]} overrun, #{x[5]} ignored"
				slf.set_option("ports",port,"rx_errors",x[1].to_i)
				slf.set_option("ports",port,"rx_crc_error",x[2].to_i)
				slf.set_option("ports",port,"rx_frame",x[3].to_i)
				slf.set_option("ports",port,"rx_overrun",x[4].to_i)
				slf.set_option("ports",port,"rx_ignored",x[5].to_i)
			end
			expect(/([0-9]+) runts, ([0-9]+) giants, ([0-9]+) throttles/) do |x|
				pinfo "#{x[1]} runts, #{x[2]} giants, #{x[3]} throttles"
				slf.set_option("ports",port,"rx_runts",x[1].to_i)
				slf.set_option("ports",port,"rx_giants",x[2].to_i)
				slf.set_option("ports",port,"rx_throttles",x[3].to_i)
			end
			expect(/([0-9]+) output errors, ([0-9]+) collisions, ([0-9]+) interface resets/) do |x|
				pinfo "#{x[1]} output errors, #{x[2]} collisions, #{x[3]} interface resets"
				slf.set_option("ports",port,"tx_errors",x[1].to_i)
				slf.set_option("ports",port,"tx_collisions",x[2].to_i)
				slf.set_option("ports",port,"tx_interface_resets",x[3].to_i)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end

		end
		self.list['ports'][port]
	end

	def setPortState(port,state)
		newstate = ( state ) ? "no shutdown\n" : "shutdown\n";
		@me.send("interface #{port}\n")
		wait("#")
		@me.send(newstate)
		wait("#")
		@me.send("exit\n")
		wait("#")
	end

	def getMacAddressByVlan(vlan)
		@me.send("show mac address-table vlan #{vlan}\n")
		self.parseMacAddress('vlan')
	end

	def getPortByMacAddress(addr)
		@me.send("show mac address-table address #{addr}\n")
		self.parseMacAddress('mac')
	end

	def getMacAddressByPort(port)
		@me.send("show mac address-table interface #{port}r\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show mac address-table\n")
		self.parseMacAddress('all')
	end

	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		@me.each do
			expect(/([0-9]+)\s+([0-9.a-f]{14})\s+(DYNAMIC|STATIC)\s+([A-Za-z0-9\\\/]+)\n/) do |x|
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
		@me.send("storm-control broadcast level pps #{speed}\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
	
	def disableHttp()
		@me.send("no ip http server\n")
		wait("#")
	end
	
	def disableHttps()
	end

	def writeCfg
		slf = self
		@me.send("copy running-config startup-config\n")
		wait("Destination filename")
		@me.send("\n")
		wait("OK")
	end
	
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("copy running-config tftp://#{host}#{dest}\n")
		wait("Address")
		@me.send("\n")
		wait("Destination")
		@me.send("\n")
		wait("copied")
	end
	def ping(host)
		@me.send("ping #{host} timeout 1 repeat 1\n")
		wait("#")
	end
	def checkPingPong
		@me.send("pwd\n")
		wait("flash")
		if @me.timeout == true
			return false
		end
		wait("#")
		return true
	end
	
	def exit()
		@me.send("exit\n")
		super
	end
end
