class AliedTemplate < Switch

	def initialize(mexp)
		super(mexp)
		@trunknames = [ "g1" ]
		@broadcastLimitAccess = 70
		@broadcastLimitTrunk = 3500
	end

	def templates()
		# set templates
		@me.templates("more") do 
			expect(/<space>/) do
				pinfo "More"
				send(" ")
			end
		end
	end

	def getAbsolutePort(port)
		if x = port.match(/e([0-9]+)/)
			return x[1]
		end
		#port.match(/g([0-9]+)/) do |x|
		#	return x[1]
		#end
		return port
	end

	def ali_expand_range(range)
		#p "ali"
		z = Array.new
		w = Array.new
		p "aliexpand"
		#p range
		range.match(/e\(?([0-9\-,]+)\)?/) do |x|
			p "Match e"
			w = expand_range(x[1])
			w = w.collect do |p|
				"e#{p}" 					
			end
		end
		range.match(/g\(?([0-9\-,]+)\)?/) do |x|
			p "Match g"
			z = expand_range(x[1])
			p z
			z = z.collect do |p|
				"g#{p}" 					
			end
		end
		
		t = w | z 
		pinfo "ali_expand_range: #{t}"
		t
	end

	def getConfiguration
		slf = self


		@me.templates("iface") do
			expect(/description (.*?)\n/) do |x|
				desc = x[1].delete('"')
				pinfo "Description #{desc}"
				slf.set_option("ports",slf.curiface,"desc",desc)
			end
			expect(/switchport trunk allowed vlan add ([0-9]+)\n/) do |x|
				pinfo "Trunk #{slf.curiface}"
				slf.curmode = "trunk"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
				slf.curvlans.push(x[1])
				pinfo "Trunk has #{slf.curvlans}"
				slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
			end
			expect(/switchport access vlan ([0-9]+)\n/) do |x|
				pinfo "Access #{slf.curiface}"
				slf.curmode = "access"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
				slf.curvlans.push(x[1])
				slf.set_option("ports",slf.curiface,"untagged",slf.curvlans)
			end
			expect(/exit/) do
				pinfo "End of section"
				# reset section variables
				slf.curiface = nil
				slf.curvlans = Array.new
				slf.curmode = nil
				break
			end
		end
		# show config
		@me.send("show running\n")
		@me.each("more") do
			expect(/hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/interface range ethernet ([0-9\-,eg\(\)]+)\n/) do |x|
				# reset section variables
				slf.curvlans = Array.new
				slf.curmode = nil
				#
				pinfo "Range #{x[1]}"
				slf.curiface = slf.ali_expand_range(x[1])
				slf.set_option("ports",slf.curiface,nil,nil)
				each("more","iface")
			end
			expect(/interface ethernet ([0-9\-,eg\(\)]+)\n/) do |x|
				# reset section variables
				slf.curvlans = Array.new
				slf.curmode = nil
				#
				pinfo "Ethernet #{x[1]}"
				slf.curiface = slf.ali_expand_range(x[1])
				slf.set_option("ports",slf.curiface,nil,nil)
				each("more","iface")
			end
			expect(/^interface vlan ([0-9]+)/) do |x|
				pinfo "Vlan #{x[1]}"
				slf.curiface = x[1].to_i
				slf.set_option("vlans",slf.curiface,nil,nil)
				each("more") do
					expect(/name (.*?)\n/) do |x|
						pinfo "Vlan name is #{x[1]}"
						slf.set_option("vlans",slf.curiface,"name",x[1])
					end
					expect(/exit/) do |x|
						pinfo "End section"		
						break
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
	
	def getPortsStatus()
		slf = self
		@me.send("show interfaces status\n")
		@me.each("more") do
			#e4       100M-Copper  Full    100   Enabled  Off  Up          Disabled Off 
			expect(/([ge0-9\/]+)\s+([0-9A-Za-z\-\/]+)\s+([0-9A-Za-z\-\/]+)\s+([0-9\-]+)\s+(Enabled|Disabled|--)\s+(Off|On|--)\s+(Up|Down|--)/) do |x|
				if x[7] == "Down" 
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
				
				pinfo "Port: #{x[1]} state #{state} speed #{speed}"
				slf.set_option("ports",x[1],"status",state)
				slf.set_option("ports",x[1],"speed",speed)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end
		end
		wait("#")
		self.list['ports']
	end
	def getPortError(port)
		slf = self
		prefix = nil
		@me.send("show int counter e #{port}\n")
		@me.each("more") do
			expect(/InUcastPkts/) do |x|
				prefix = 'rx'	
			end
			expect(/OutUcastPkt/) do |x|
				prefix = 'tx'
			end
			expect(/\s+([e0-9]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+)\s+([0-9]+)/) do |x|
				port = x[1]
				bytes = x[5].to_i
				pinfo "#{prefix}_bytes=#{bytes}"	
				slf.set_option("ports",port,"#{prefix}_bytes",bytes)	
			end

			expect(/FCS Errors: ([0-9]+)/) do |x|
				pinfo "rx_crc_error=#{x[1]}"	
				slf.set_option("ports",port,"rx_crc_error",x[1].to_i)
			end
			expect(/Single Collision Frames: ([0-9]+)/) do |x|
				pinfo "rx_single_collision_frames=#{x[1]}"	
				slf.set_option("ports",port,"rx_single_collision_frames",x[1].to_i)
			end
			expect(/Late Collisions: ([0-9]+)/) do |x|
				pinfo "rx_late_collisions=#{x[1]}"	
				slf.set_option("ports",port,"rx_late_collisions",x[1].to_i)
			end
			expect(/Excessive Collisions: ([0-9]+)/) do |x|
				pinfo "rx_excessive_collisions=#{x[1]}"	
				slf.set_option("ports",port,"rx_excessive_collisions",x[1].to_i)
			end
			expect(/Oversize Packets: ([0-9]+)/) do |x|
				pinfo "rx_oversize packets=#{x[1]}"	
				slf.set_option("ports",port,"rx_oversize packets",x[1].to_i)
			end
			expect(/Internal MAC Rx Errors: ([0-9]+)/) do |x|
				pinfo "rx_internal_mac_rx_error=#{x[1]}"	
				slf.set_option("ports",port,"rx_internal_mac_rx_error",x[1].to_i)
			end
			expect(/Received Pause Frames: ([0-9]+)/) do |x|
				pinfo "rx_receive_pause_frames=#{x[1]}"	
				slf.set_option("ports",port,"rx_receive_pause_frames",x[1].to_i)
			end
			expect(/Transmitted Pause Frames: ([0-9]+)/) do |x|
				pinfo "rx_transmitted_pause_frames:#{x[1]}"	
				slf.set_option("ports",port,"rx_transmitted_pause_frames",x[1].to_i)
			end

			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end

		end

		self.list['ports'][port]
	end
	def clearPortCounter(port)
		@me.send("clear counters ethernet #{port}\n")
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
		@me.send("show bridge address-table vlan #{vlan}\n")
		self.parseMacAddress('vlan')
	end
	def getMacAddressByPort(port)
		@me.send("show bridge address-table ethernet #{port}\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show bridge address-table\n")
		self.parseMacAddress('all')
	end
	def getPortByMacAddress(addr)
		@me.send("show bridge address-table address #{addr}\n")
		self.parseMacAddress('mac')
	end
	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		wait("Aging time")
		@me.each do
			expect(/\s+?([0-9]+)\s+([0-9a-f:]+)\s+([A-Za-z0-9\\\/]+)\s+dynamic\s+\n/) do |x|
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
	def ConfigurationMode
		@me.send("conf\n")
		self.wait(/\(config\)#/)
		yield
		@me.send("exit\n")
		self.wait(/#/)
	end
	def disableHttp()
		@me.send("no ip http server\n")
		self.wait(/\(config/)
	end
	def disableHttps()
	end
	def setBroadcastStorm(port,speed)
		slf = self
		@me.send("interface ethernet #{port}\n")
		self.wait(/\(config/)
		@me.send("port storm-control broadcast enable\n")
		self.wait(/\(config/)
		@me.send("port storm-control broadcast rate #{speed}\n")
		self.wait(/\(config/)
		@me.send("exit\n")
		self.wait(/\(config/)
	end
	def writeCfg
		slf = self
		pinfo "Write config"
		@me.send("copy running-config startup-config\n")
		wait("[Yes/press any key for no]")
		@me.send("y")
		wait("succeeded")
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("copy running-config tftp://#{host}#{dest}\n")
		wait("copied")
	end
	def ping(host)
		@me.send("ping #{host} count 1 timeout 50\n")	
		wait("#")
	end
	def exit()
		@me.send("exit\n")
		super
	end
	def setSnmpSettings(host,community)
		@me.send("snmp-server community #{community} ro #{host} view Default\n")
		wait("#")
	end
end

