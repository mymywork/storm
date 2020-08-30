require_relative 'templates/cisco_template.rb'
 
class Cisco3550 < CiscoTemplate
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 1900
	end

end



