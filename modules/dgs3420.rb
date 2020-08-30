require_relative 'templates/des3200_template.rb'
 
class DGS3420 < DES3200Template

	def initialize(mexp)
		super
		@trunknames = [ "25" , "26" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
	end

end



