
class Qtech25 < Switch
	
	def initialize(mexp)
		super(mexp)
		@broadcast_enable=false
		@trunknames = [ "9", "10" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
		@mactable = Hash.new
	end

	def enableMode()
		slf = self
		@me.send("en\n")
		@me.each do
			expect(/Password/) do
				pinfo "Enter in privileged mode"
				send("#{slf.enablePassword}\n")
			end
			expect(/#|>/) do
				pinfo "Detected Prompt"
				break
			end
		end
	end

	def getConfiguration
		slf = self

		@me.templates("more") do
			expect(/--More--/) do
				pinfo "More"
				# preserve 100 pages
				send(" "*100)
			end
		end

		@me.send("show running\n")
		@me.each("more") do
			expect(/^hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/interface port ([0-9\/]+)\s+?\n/) do |x|
				pinfo "Port #{x[1]}"
				# init section variables
				slf.curiface = x[1]
				slf.curvlans = Array.new
				slf.curmode = nil
				# 
				slf.set_option("ports",slf.curiface,nil,nil)
				each("more") do 
					expect(/description (.*?)\n/) do |x|
						desc = x[1].delete('"')
						pinfo "Description #{desc}"
						slf.set_option("ports",slf.curiface,"desc",desc)
					end
					expect(/switchport mode trunk\s+?/) do |x|
						pinfo "Trunk #{slf.curiface}"
						slf.curmode = "trunk"
						slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans.push("2-4094")
						slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
					end
					expect(/switchport trunk allowed vlan ([0-9;]+)\s+?\n/) do |x|
						pinfo "Trunk allowed #{slf.curiface} vlans #{x[1]}"
						slf.curmode = "trunk"
						slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans = x[1].split(";")
						slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
					end
					expect(/switchport access vlan ([0-9]+)\s+?\n/) do |x|
						pinfo "Access #{slf.curiface} vlan #{x[1]}"
						slf.curmode = "access"
						slf.set_option("ports",slf.curiface,"mode",slf.curmode)
						slf.curvlans.push(x[1])
						slf.set_option("ports",slf.curiface,"untagged",slf.curvlans)
					end
					expect(/^!/) do
						pinfo "End section"
						break
					end
				end
			end
			expect(/^vlan ([0-9]+)\n/) do |x|
				pinfo "Vlan #{x[1]}"
				slf.curiface = x[1].to_i
				slf.set_option("vlans",slf.curiface,nil,nil)
				each("more") do
					expect(/name (.*?)\n/) do |x|
						pinfo "Vlan name is #{x[1]}"
						slf.set_option("vlans",slf.curiface,"name",x[1])
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
		@me.send("conf\n")
		self.wait(/\(config\)#/)
		yield
		@me.send("exit\n")
		self.wait(/#/)
	end
	def getPortsStatus()
		slf = self
		@me.send("show int port\n")
		@me.each do
			#2     enable up      (100M/full)  auto         off/off      enable   Block
			expect(/([0-9]+)\s+(enable\s|disable)([a-z]+)\s+(\([a-zA-Z0-9\/]+\))?\s+([a-zA-Z0-9\/]+)\s+([a-zA-Z0-9\/]+)\s+([a-zA-Z0-9\/]+)\s+([a-zA-Z0-9\/]+)\s+\n/) do |x|
				# port state
				if x[3] == "up" 
					state = "UP"
				else
					state = "DOWN"
				end
				# admin state
				if x[2] == "disable"
					state = "A-DOWN"
				end
				pinfo "Port: #{x[1]} state #{state}"
				slf.set_option("ports",x[1],"status",state)
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
		@me.send("show int port #{port} statistics")
		@me.each do
			#
			# traffic 
			#
			expect(/InOctets:\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_bytes=#{val}"	
				slf.set_option("ports",port,"rx_bytes",val.to_i)
			end
			expect(/OutOctets:\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_bytes=#{val}"	
				slf.set_option("ports",port,"tx_bytes",val.to_i)
			end
			#
			# rx errors
			#
			expect(/DropEvents\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_drop_events=#{val}"	
				slf.set_option("ports",port,"rx_drop_events",val.to_i)
			end
			expect(/CRCAlignErrors\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_crc_error=#{val}"	
				slf.set_option("ports",port,"rx_crc_error",val.to_i)
			end
			expect(/UndersizePkts:\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_undersize=#{val}"	
				slf.set_option("ports",port,"rx_undersize",val.to_i)
			end
			expect(/OversizePkts:\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_oversize=#{val}"	
				slf.set_option("ports",port,"rx_oversize",val.to_i)
			end
			expect(/Fragments\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_fragments=#{val}"	
				slf.set_option("ports",port,"rx_fragments",val.to_i)
			end
			expect(/Jabbers\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_jabber=#{val}"	
				slf.set_option("ports",port,"rx_jabber",val.to_i)
			end
			expect(/Collisions\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "rx_collisions=#{val}"	
				slf.set_option("ports",port,"rx_collisions",val.to_i)
			end
			#
			# tx errors
			#
			expect(/OutputError\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_error=#{val}"	
				slf.set_option("ports",port,"tx_error",val.to_i)
			end
			expect(/OutputDiscard\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_discard=#{val}"	
				slf.set_option("ports",port,"tx_discard",val.to_i)
			end
			expect(/Abort\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_abort=#{val}"	
				slf.set_option("ports",port,"tx_abort",val.to_i)
			end
			expect(/Differred\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_differred=#{val}"	
				slf.set_option("ports",port,"tx_differred",val.to_i)
			end
			expect(/LateCollisions\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_late_collisions=#{val}"	
				slf.set_option("ports",port,"tx_late_collisions",val.to_i)
			end
			expect(/NoCarrier\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_no_carrier=#{val}"	
				slf.set_option("ports",port,"tx_no_carrier",val.to_i)
			end
			expect(/LostCarrier\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_lost_carrier=#{val}"	
				slf.set_option("ports",port,"tx_lost_carrier",val.to_i)
			end
			expect(/MacTransmitError\(Pkts\):\s+([0-9,]+)/) do |x|
				val = x[1].delete(',')
				pinfo "tx_mac_transmit_error=#{val}"	
				slf.set_option("ports",port,"tx_mac_transmit_error",val.to_i)
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end

		end
		self.list['ports'][port]
	end
	def clearPortCounter(port)
		self.ConfigurationMode() do
			@me.send("clear interface port #{port} statistics")
			wait("#")
		end
	end
	def setPortState(port,state)
		newstate = ( state ) ? "no shutdown\n" : "shutdown\n";
		@me.send("interface port #{port}\n")
		wait("#")
		@me.send(newstate)
		wait("#")
		@me.send("exit\n")
		wait("#")
	end
	def getMacAddressByVlan(vlan)
		slf = self
		@me.send("show mac-address-table l2-address vlan #{vlan}\n")
		parseMacAddress('vlan')
	end
	def getMacAddressByPort(port)
		slf = self
		@me.send("show mac-address-table l2-address port #{port}\n")
		parseMacAddress('port')
	end
	def getPortByMacAddress(addr)
		slf = self
		@me.send("show mac-address-table l2-address | include #{self.macToCisco(addr).upcase()}\n")
		parseMacAddress('mac')
	end
	def parseMacAddress(groupkey)
		slf = self
		wait("$")
		@me.each do
			expect(/([0-9A-F.:-]+)[\s\t]+([0-9]+)\s+([0-9]+)\s+([A-Za-z]+)\n/) do |x|
				#mac = slf.macToNormal(x[1])
				#vlan = x[3]
				#port = x[2]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = port			
				
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[1])
				lst['vlan'] = x[3]
				lst['port'] = x[2]
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

	def ConfigurationMode
		@me.send("conf t\n")
		self.wait(/\(config\)#/)
		yield
		@me.send("exit\n")
	end

	def setBroadcastStormEnable(speed)
		if !@broadcast_enable
			@me.send("storm-control bps #{speed}\n")
			wait(/config/)
			@me.send("storm-control broadcast enable\n")
			wait(/config/)
			@broadcast_enable=true
		end
	end

	def setBroadcastStorm(port,speed)
		slf = self
		setBroadcastStormEnable(speed)
		@me.send("storm-control broadcast enable port #{port}\n")
		self.wait(/\(config/)
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("upload startup-config tftp #{host} #{dest}\n")
		slf.wait("Success!")
	end
	def writeCfg
		slf = self
		@me.send("write\n")
		wait("successful")
	end
	def ping(host)
		@me.send("ping #{host} count 1 waittime 1")	
		wait("#")
	end
	def exit()
		@me.send("exit")
		super
	end
end



