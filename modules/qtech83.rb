require_relative 'templates/qtech28_template.rb'

class Qtech83 < Qtech28Template
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
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



