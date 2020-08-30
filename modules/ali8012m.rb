
class Alied8012M < Switch

	attr_accessor :portinvalid

	def initialize(mexp)
		super(mexp)
		@trunknames = [ "12" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 1900
		@portinvalid = false
	end

	def getConfiguration
		slf = self
		@me.send("c")
		@me.each do
			expect(/\$/) do
				break
			end
		end
		@me.send("show vlan\r")
		@me.each do
			expect(/VLAN ID[\s\.]+([0-9\-,]+)\n/) do |x|
				pinfo "Parse VID #{x[1]}"
				# reset section variables
				slf.curvlans = Array.new
				slf.curvlans.push(x[1])
				slf.curiface = nil
				slf.curmode = nil
			end
			expect(/Tagged Port\(s\)[\s\.]+([0-9\-,\s]+)\n/) do |x|
				pinfo "Parse Tagged #{x[1]}"
				slf.curiface = slf.expand_range(x[1].delete(" "))
				slf.curmode = "trunk"
				slf.set_port_option(slf.curiface,"mode",slf.curmode)
				pinfo "Trunk has #{slf.curvlans}"
				slf.set_port_option(slf.curiface,"tagged",slf.curvlans)
			end
			expect(/Untagged Port\(s\)[\s\.]+([0-9\-,\s]+)\n/) do |x|
				pinfo "Parse Untagged #{x[1]}"
				slf.curiface = slf.expand_range(x[1].delete(" "))
				slf.curmode = "access"
				slf.set_port_option(slf.curiface,"mode",slf.curmode)
				pinfo "Access has #{slf.curvlans}"
				slf.set_port_option(slf.curiface,"untagged",slf.curvlans)
			end
			expect(/\<Space\>/) do
				pinfo "More"
				send(" ")
			end
			expect(/\$/) do
				pinfo "Detected prompt"
				break
			end
		end
		@me.send("m\r")
		wait("Enter your selection")
		
		self.setUnconfiguredAccess()
		
		return self.ports 
	end

	def getMacAddressByVlan(vlan)
		{}
	end
	
	def getPortByMacAddress(addr)
		{}
	end
		
	def ConfigurationMode
		yield
	end
	def setBroadcastStorm(port,speed)
		slf = self
		slf.portinvalid=false
		@me.send("1")		#Port Menu
		wait("Enter your selection\?")
		@me.send("1")		#Port Configuration
		wait("Enter Ports List")
		@me.send("#{port}\r")		#Ports List
		@me.each do
			expect(/Enter your selection/) do |x|
				pwarn "FOUND Enter your selection"
				break
			end
			expect(/Some ports in the list are invalid/) do |x|
				pwarn "FOUND Some ports in the list are invalid"
				send("\n")
				slf.portinvalid = true
				break
			end
		end
		if !slf.portinvalid 
			@me.send("c")		#Broadcast Control
			wait("Enter Max. Broadcasts")
			@me.send("#{speed}\r")	#Set speed
			wait("Enter your selection\?")
			@me.send("r")		#Return to main menu
		end
		wait("Enter your selection\?")
		@me.send("r")		#Return to main menu
	end
	def writeCfg
		slf = self
		@me.send("s")
		wait("updating flash")
	end
end



