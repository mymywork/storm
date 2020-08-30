require_relative 'templates/qtech28_template.rb'
 
class Qtech28 < Qtech28Template
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ "Ethernet1/25" , "Ethernet1/26" , "Ethernet1/27" , "Ethernet1/28" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
	end

	def getAbsolutePort(port)
		if x = port.match(/1\/([0-9]+)/)
			return x[1]
		end
		return port
	end
end



