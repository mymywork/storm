require_relative 'templates/des3200_template.rb'

class DES3200RevA < DES3200Template

	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("upload cfg_toTFTP #{host} #{dest}\n")
		wait("Success")
	end
	def setSeverity()
		@me.send("config syslog host 1 severity informational\n")
		wait("Success")
	end
end



