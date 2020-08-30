require_relative 'templates/dgs1100_template.rb'
 
class DGS1100RevA < DGS1100Template 

	def initialize(me)
		me.reconnect(true) if me.mode == 0
		super
		if me.mode == 0
			login()
		end
	end	
	def setSeverity()
		@me.send("config syslog host 1 severity informational")
		wait("Success")
	end
end



