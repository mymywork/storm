require_relative 'templates/cisco_template.rb'

class Cisco3750 < CiscoTemplate
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
		@broadcastLimitAccess = "64"
		@broadcastLimitTrunk = "1900"
	end

	def setBroadcastStorm(port,speed)
		slf = self
		@me.send("interface #{port}\n")
		@me.send("storm-control broadcast level pps #{speed}\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
end



