require_relative 'templates/qtech28_template.rb'

class Qtech27 < Qtech28Template
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ "Ethernet0/0/25" , "Ethernet0/0/26" , "Ethernet0/0/27" , "Ethernet0/0/28" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
	end

	def getAbsolutePort(port)
		if x = port.match(/0\/0\/([0-9]+)/)
			return x[1]
		end
		return port
	end
	def getPortByMacAddress(addr)
		@me.send("show mac-address-table address #{macToDash(addr)}\n")
		self.parseMacAddress('mac')
	end
end



