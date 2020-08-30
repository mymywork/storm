# Template by default for Rev.A
#

class DGS1100Template < Switch

	def initialize(mexp)
		super(mexp)
		@trunknames = [ "6" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 960
	end

	def templates()
		super()	
		@me.templates("more") do
			expect(/(More|Next Entry|SPACE)/) do
				pinfo "Send space for next entry"
				send("a")
			end
		end
	end
	def getConfiguration
		slf = self
		# reset section variables
		slf.curiface = nil
		slf.curvlans = Array.new
		slf.curmode = nil
		@me.send("show config current_config\n")
		@me.each do
			#
			# Hostname
			#
			expect(/config snmp system_name (.*?)\n/) do |x|
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			#
			# Ports descriptions
			#
			expect(/config ports ([0-9,-]+) .*?description (.*?)\n/) do |x|
				desc = x[2].delete('"')
				pinfo desc
				slf.set_option("ports",slf.expand_range(x[1]),"desc",desc)
			end
			#
			# Ports mode and tagged/untagged vlans
			#
			expect(/create vlan (.*?) tag ([0-9]+)/) do |x|
				desc = x[1].delete('"')
				vlan = x[2]
				pinfo "Vlan #{vlan} #{desc}"
				slf.set_option("vlans",vlan,"name",desc)
			end
			expect(/config vlan vlanid ([0-9]+) add tagged ([0-9\-,]+)\n/) do |x|
				pinfo "Parse Tagged #{x[1]}"
				slf.curvlans = Array.new
				slf.curvlans.push(x[1])
				slf.curiface = slf.expand_range(x[2])
				slf.curmode = "trunk"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
				pinfo "Trunk has #{slf.curvlans}"
				slf.set_option("ports",slf.curiface,"tagged",slf.curvlans)
			end
			expect(/config vlan vlanid ([0-9]+) add untagged ([0-9\-,]+)\n/) do |x|
				pinfo "Parse Untagged #{x[1]}"
				slf.curvlans = Array.new
				slf.curvlans.push(x[1])
				slf.curiface = slf.expand_range(x[2])
				slf.curmode = "access"
				slf.set_option("ports",slf.curiface,"mode",slf.curmode)
				pinfo "Access has #{slf.curvlans}"
				slf.set_option("ports",slf.curiface,"untagged",slf.curvlans)
			end
			expect(/SPACE/) do
				pinfo "More"
				send("a")
			end
			expect(/flood_fdb|End of configuration file/) do
				pinfo "End of config"
				break
			end
		end
		
		self.setUnconfiguredAccess()
	end
	def getPortsStatus
		slf = self
		lastport = 0
		combostate = nil
		@me.send("show ports\n")
		@me.each do
			#
			# Status
			#
			# dgs 3624 (SORM) ([\s\t]{0,}\(.\))?
			expect(/([0-9]+)[\s\t]{0,}(\(.\))?[\s\t]+([A-Za-z0-9_\-\/]+)[\s\t]+([A-Za-z0-9_\-\/]+)[\s\t]+(Link Down|[A-Za-z0-9_\-\/]+)[\s\t]+([A-Za-z0-9_\-\/]+)[\s\t]+\n/) do |x|
				port = x[1]
				status = x[5]
				#p x
				#
				pwarn x[4]
				speed = 0
				if status == "Err-Disabled"
					state = "ERR"
				elsif status == "Link Down" || status == "LinkDown"
					state = "DOWN"
				elsif status =~ /100M/
					state = "UP"
					speed = 100
				elsif status =~ /1000M/
					state = "UP"
					speed = 1000
				elsif status =~ /10G/
					state = "UP"
					speed = 10000
				else
					speed = 0
					state = "UP"
				end

				# prevent rewrite copper port on last we need break 
				if lastport == slf.portsnum.to_i && state == "DOWN" && combostate == "UP" 
					pinfo "Reach last port in output. -> send q"
					send("q")
					break
				end
				# prevent rewrite copper port 
				next if lastport == x[1].to_i && state == "DOWN" && combostate == "UP" 
				combostate = state

				pinfo "Port #{x[1]} state #{state} speed #{speed}"
				slf.set_option("ports",x[1],"status",state)
				slf.set_option("ports",x[1],"speed",speed)
				# check second update of ports screen
				if lastport > x[1].to_i
					# save lastport
					lastport = x[1].to_i
					pinfo " --- last port #{lastport}"
					pinfo "Detected 2nd port output update -> send space"
					send(" ")
					next
				end
				# save lastport
				lastport = x[1].to_i
				pinfo " --- last port #{lastport}"
				# reach last number port
				pinfo "Portsnum #{slf.portsnum}"
				if lastport == slf.portsnum.to_i && ( x[2] == "(F)" || x[2] == nil )
					pinfo "Reach last port in output. -> send q"
					send("q")
					break
				end

			end
		end
		# wait for ending
		wait("#")
		self.list['ports']
	end
	def getPortError(port)
		slf = self
		lastport = nil
		@me.send("show error port #{port}\n")
		wait("Port Number")
		@me.each("more") do
			# CRC Error 0 Excessive Deferral 0  
			expect(/CRC Error\s+([0-9]+)\s+Excessive Deferral\s+([0-9]+)/) do |x|
				pinfo "crc_error=#{x[1]} excessive_defferal=#{x[2]}"
				slf.set_option("ports",port,"rx_crc_error",x[1].to_i)
				slf.set_option("ports",port,"tx_excessive_deferral",x[2].to_i)
			end
			# Undersize 0 CRC Error 0 
			expect(/Undersize\s+([0-9]+)\s+CRC Error\s+([0-9]+)/) do |x|
				pinfo "undersize=#{x[1]} crc_error=#{x[2]}"
				slf.set_option("ports",port,"rx_undersize",x[1].to_i)
				slf.set_option("ports",port,"tx_crc_error",x[2].to_i)
			end
			# Oversize 0 Late Collision 0 
			expect(/Oversize\s+([0-9]+)\s+Late Collision\s+([0-9]+)/) do |x|
				pinfo "oversize=#{x[1]} late_collision=#{x[2]}"
				slf.set_option("ports",port,"rx_oversize",x[1].to_i)
				slf.set_option("ports",port,"tx_late_collision",x[2].to_i)
			end
			# Fragment 0 Excessive Collision 0 
			expect(/Fragment\s+([0-9]+)\s+Excessive Collision\s+([0-9]+)/) do |x|
				pinfo "fragment=#{x[1]} excessive_collision=#{x[2]}"
				slf.set_option("ports",port,"rx_fragment",x[1].to_i)
				slf.set_option("ports",port,"tx_excessive_collision",x[2].to_i)
			end
			# Jabber 0 Single Collision 0 
			expect(/Jabber\s+([0-9]+)\s+Single Collision\s+([0-9]+)/) do |x|
				pinfo "jabber=#{x[1]} single_collision=#{x[2]}"
				slf.set_option("ports",port,"rx_jabber",x[1].to_i)
				slf.set_option("ports",port,"tx_single_collision",x[2].to_i)
			end
			# Drop Pkts 0 Collision 0 
			expect(/Drop Pkts\s+([0-9]+)\s+Collision\s+([0-9]+)/) do |x|
				pinfo "drop_pkts=#{x[1]} collision=#{x[2]}"
				slf.set_option("ports",port,"rx_drop_pkts",x[1].to_i)
				slf.set_option("ports",port,"tx_collision",x[2].to_i)
			end
			# Symbol Error 0 
			expect(/Symbol Error\s+([0-9]+)/) do |x|
				pinfo "symbol_error=#{x[1]}"
				slf.set_option("ports",port,"rx_symbol_error",x[1].to_i)
			end
			# quit
			expect(/Port Number/) do |x|
				pinfo "Quit"
				send("q")
				break
			end
		end
		wait("#")
		@me.send("show packet port #{port}\n")
		@me.each do
			# RX Bytes  
			expect(/RX Bytes\s+([0-9]+)\s+([0-9]+)\s{0,}\n/) do |x|
				pinfo "rx_bytes=#{x[1]}"
				slf.set_option("ports",port,"rx_bytes",x[1].to_i)
			end
			# TX Bytes  
			expect(/TX Bytes\s+([0-9]+)\s+([0-9]+)\s{0,}\n/) do |x|
				pinfo "tx_bytes=#{x[1]}"
				slf.set_option("ports",port,"tx_bytes",x[1].to_i)
			end
			# quit
			expect(/Broadcast/) do |x|
				pinfo "Quit"
				send("q")
				break
			end
		end

		self.list['ports'][port]
	end
	def clearPortCounter(port)
		@me.send("clear counters port #{port}")
		wait("Success")
	end
	def setPortState(port,state)
		newstate = ( state ) ? "enable" : "disable";
		@me.send("config ports #{port} state #{newstate}\n")
		wait("#")
	end
	def getMacAddressByVlan(vlan)
		@me.send("show fdb vlanid #{vlan}\n")
		self.parseMacAddress('vlan')
	end
	def getMacAddressByPort(port)
		@me.send("show fdb port #{port}\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show fdb\n")
		self.parseMacAddress('all')
	end
	def getPortByMacAddress(addr)
		@me.send("show fdb mac_address #{addr}\n")
		self.parseMacAddress('mac')
	end
	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		wait("Command")
		@me.each do
			expect(/^([0-9]+)\s+[a-zA-Z0-9\-_]+[\s\t]+([0-9A-F-]+)\s+([0-9]+)[\s\t]+[A-Za-z\s\t]+\n/) do |x|
				#mac = slf.macToNormal(x[2])
				#vlan = x[1]
				#port = x[3]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = { :port => port, :vlan => vlan }			
				
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[2])
				lst['vlan'] = x[1].to_i
				lst['port'] = x[3]
				pinfo lst
				slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
				slf.mactable[lst[groupkey]].push(lst)
			end
			expect(/Next Entry/) do
				pinfo "More"
				send("a")
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return slf.mactable
	end

	def ConfigurationMode
		yield
	end
	def setBroadcastStorm(port,speed)
		slf = self
		@me.send("config traffic control #{port} broadcast enable multicast disable unicast disable action drop threshold #{speed}\n")
	end
	def writeCfg
		slf = self
		@me.send("save\n")
		wait("OK")
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("upload cfg_toTFTP #{host} #{dest}\n")
		wait(/Success|Failure/)
	end
	def ping(host)
		@me.send("ping #{host} times 1 timeout 1\n")	
		wait("Command")
		wait("#")
	end
	def setSnmpTrapHost(host,community)
		@me.send("create snmp host #{host} v2c #{community}\n")	
		wait("#")
	end
	def removeSnmpTrapHost(host,community)
		@me.send("delete snmp host #{host}\n")
		wait("#")
	end
	def enablePasswordEncryption()
		@me.send("enable password encryption\n")
		wait("#")
	end
	def disableHttp()
		@me.send("disable web\n")
		wait("#")
	end
	
	def disableHttps()
	end
	def exit()
		@me.send("logo\n")
		super
	end
end



