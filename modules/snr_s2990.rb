require_relative 'templates/qtech28_template.rb'

class SnrS2990 < Qtech28Template
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ "Ethernet1/0/25" , "Ethernet1/0/26" , "Ethernet1/0/27" , "Ethernet1/0/28" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
	end

	def getAbsolutePort(port)
		if x = port.match(/1\/0\/([0-9]+)/)
			return x[1]
		end
		return port
	end
end



