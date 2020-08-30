require_relative 'templates/des3200_template.rb'
 
class DES3526 < DES3200Template

	def initialize(mexp)
		super(mexp)
		@trunknames = [ "25" , "26" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
	end
	def getMacAddressByVlan(vlan)
		@me.send("show fdb vid #{vlan}\n")
		self.parseMacAddress()
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("upload cfg_toTFTP #{host} #{dest}\n")
		wait("#")
	end

end



