require_relative 'templates/des3200_template.rb'

class DES3200RevC < DES3200Template
	
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("upload cfg_toTFTP #{host} dest_file #{dest}\n")
		wait("Success")
	end
	def setSeverity()
		@me.send("config syslog host 1 severity 6\n")
		wait("Success")
	end
end
