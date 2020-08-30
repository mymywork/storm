class BDCOMTemplate < Switch

	def initialize(mexp)
		super(mexp)
		@ifacenames = { 
			'GigaEthernet' => 'g',
			'EPON' => 'epon'
		}
	end
	
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

	def getAbsolutePort(port)
		if x = port.match(/(0\/[0-9:]+)/)
			return x[1]
		end
		return port
	end
	
	def getConfiguration
		slf = self
		
		# getting config
		#
		@me.send("show config\n")
		@me.each("more") do
			expect(/hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/interface (GigaEthernet|EPON)([0-9\/:]+)\n/) do |x|
				pinfo "#{x[1]} - #{x[2]}"
				# reset section variables
				slf.curiface = "#{slf.typeLongToShort(x[1])}#{x[2]}"
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
					expect(/switchport trunk vlan-allowed ([0-9;]+)\n/) do |x|
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
		@me.send("conf\n")
		self.wait(/config#/)
		yield
		@me.send("exit\n")
		self.wait(/#/)
	end

	def getPortsStatus()
		slf = self
		@me.send("show int br\n")
		# wait start command
		wait(/Port[\s\t]+Description[\s\t]+Status[\s\t]+Vlan[\s\t]+Duplex[\s\t]+Speed[\s\t]+Type/)
		@me.each("more") do
			#g0/1   100-uplink up        Trunk(2900) auto     auto     GigaEthernet-TX
			#epon0/1:1                up                    full     1000Mb   GigaEthernet-LLID 
			#g0/5                  up        3104        full     1000Mb   Giga-FX
			expect(/([A-Za-z0-9\/:]+)\s+(.*?)?\s+(up|down|shutdown)\s+([A-Za-z\(\)0-9]+)?\s+(auto|full|half)?\s+([a-zA-Z0-9]+)?\s+(.*?)/) do |x|
				
				if x[3] == "down"
					state = "DOWN"
				elsif x[3] == "shutdown"
					state = "A-DOWN"
				else
					state = "UP"
				end
			
				if x[6] =~ /10000/
					speed = 10000
				elsif x[6] =~ /1000/
					speed = 1000
				elsif x[6] =~ /100/
					speed = 100
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
		slf = self
		@me.send("show int #{port}\n")
		@me.each("more") do
			expect(/Received ([0-9]+) packets, ([0-9]+) bytes/) do |x|
				pinfo "rx_bytes=#{x[2]}"	
				slf.set_option("ports",port,"rx_bytes",x[2].to_i)
			end
			#expect(/([0-9]+) broadcasts, ([0-9]+) multicasts/) do |x|
			#	pinfo "rx_broadcast=#{x[1]} rx_multicasts=#{x[2]}"	
			#	slf.set_option("ports",port,"rx_bytes",x[2].to_i)
			#end
			expect(/Transmited ([0-9]+) packets, ([0-9]+) bytes/) do |x|
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

	def enableMode()
		@me.send("su\n")	
		wait("#")
	end

	def disbaleMode()
			
	end

	def getPONFromClientToHeadSignal(iface)
		signal = nil
		@me.send("show epon optical-transceiver-diagnosis interface epON #{iface}\n")	
		@me.each do
			expect(/^epon[0-9\/:]+[\t\s]+([0-9\-.]+)/) do |x|
				signal = x[1]
				pinfo "Head #{x[1]}"
			end
			expect(/invalid/) do
				break
			end
			expect(/#/) do
				break
			end
		end
		signal
	end

	def getPONFromHeadToClientSignal(iface)
		signal = nil
		@me.send("show epon interface epON #{iface} onu ctc optical-transceiver-diagnosis\n")	
		@me.each do
			expect(/received power\(DBm\):[\s\t]+([0-9\-.]+)/) do |x|
				signal = x[1]
				pinfo "Terminal #{signal}"
			end
			expect(/invalid/) do
				break
			end
			expect(/#/) do
				break
			end
		end
		signal
	end
	# show epon interface epON 0/1:9 onu pon-port statistic
	def getPONClientPortsError(iface)
		list = Hash.new
		@me.send("show epon interface ePON #{iface} onu pon-port statistics\n")
		catchData('ponport',list)
		@me.send("show epon interface ePON #{iface} onu port 1 state\n")
		catchData('port_1',list)
		@me.send("show epon interface ePON #{iface} onu port 1 statistics\n")
		catchData('port_1',list)
		#@me.send("show epon interface ePON #{iface} onu port 2 state\n")
		#catchData('port_2',list)
		#@me.send("show epon interface ePON #{iface} onu port 2 statistics\n")
		#catchData('port_2',listi)
		list
	end
	def catchData(port,list)
		@me.each do
			setTimeout(40)
			expect(/([a-zA-Z0-9 \/\-]+Frames|Octets|state|Speed|Duplex[a-zA-Z0-9 ]+)\s+(:|is) ([0-9\-A-Za-z]+)/) do |x|
				key = x[1].strip
				val = x[3]
				list[port] = Hash.new if list[port] == nil
				list[port][key] = val
				pinfo "#{x[1]} = #{x[2]}"
			end
			expect(/invalid/) do
				break
			end
			expect(/#/) do
				break
			end
		end
	end

	def clearPortCounter(port)
#		@me.send("clear counters interface ethernet #{port}")
#		wait("#")
	end
	def setPortState(port,state)
#		newstate = ( state ) ? "no shutdown\n" : "shutdown\n";
#		@me.send("interface ethernet #{port}\n")
#		wait("#")
#		@me.send(newstate)
#		wait("#")
#		@me.send("exit\n")
#		wait("#")
	end
	def isPonPort(port)
		return true if port =~ /[0-9]+\/[0-9]+/
		return false
	end
	def getMacAddressByVlan(vlan)
		@me.send("show mac address-table dynamic vlan #{vlan}\n")
		self.parseMacAddress('vlan')
	end
	def getMacAddressByPort(port)
		@me.send("show mac address-table interface epon #{port}\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show mac address-table\n")
		self.parseMacAddress('all')
	end
	
	def getPortByMacAddress(addr)
		@me.send("show mac address-table #{macToCisco(addr)}\n")
		self.parseMacAddress('mac')
	end
	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		@me.each("more") do
			expect(/^([0-9]+)\s+([0-9a-f:.-]+)\s+(DYNAMIC|STATIC)\s+([A-Za-z0-9\\\/:]+)\n/) do |x|
				#mac = slf.macToNormal(x[2])
				#vlan = x[1]
				#port = x[4]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = { :port => port, :vlan => vlan }			
				
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[2])
				lst['vlan'] = x[1].to_i
				lst['fullport'] = x[4]
				lst['port'] = x[4].gsub(/[a-z]+/,'')
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

	def setBroadcastStorm(port,speed)
#		slf = self
#		@me.send("interface #{port}\n")
#		@me.send("storm-control broadcast #{speed}\n")
#		@me.send("exit\n")
#		self.wait(/\(config/)
	end
	def writeCfg
		slf = self
		@me.send("write all\n")
		wait("OK!")
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("copy startup-config tftp #{host}\n")
		slf.wait("Destination")
		@me.send("#{dest}\n")
		wait("successfully")
		wait("#")
	end
	def ping(host)
		@me.send("ping #{host} -w 0")	
		wait("#")
	end
	
	def setSnmpTrapHost(host,community)
#		@me.send("snmp-server host #{host} v2c #{community}")	
#		wait("#")
	end
	def removeSnmpTrapHost(host,community)
#		@me.send("no snmp-server host #{host} v2c #{community}")
#		wait("#")
	end

	def disableHttp()
		@me.send("no ip http server\n")
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



