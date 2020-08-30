require_relative 'templates/cisco_template.rb'

class Cisco2950 < CiscoTemplate
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
		@broadcastLimitAccess = 1
		@broadcastLimitTrunk = 1
	end

	def setBroadcastStorm(port,speed)
		slf = self
		@me.send("interface #{port}\n")
		@me.send("storm-control broadcast level #{speed}\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
	def ping(host)
		@me.send("ping #{host}")	
		wait("#")
	end
end



