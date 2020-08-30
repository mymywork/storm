require_relative 'templates/qtech28_template.rb'

class SnrS2965 < Qtech28Template
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ "Ethernet1/0/25" , "Ethernet1/0/26" , "Ethernet1/0/27" , "Ethernet1/0/28" ]
		@broadcastLimitAccess = 64
		@broadcastLimitTrunk = 912
	end

	def getAbsolutePort(port)
		if x = port.match(/1\/0\/([0-9]+)/)
			return x[1]
		end
		return port
	end
	def getPortByMacAddress(addr)
		slf = self
		slf.mactable = Hash.new
		# QTECH 2700 !
		@me.send("show mac-address-table address #{slf.macToDash(addr)}\n")
		return parseMacAddress('mac')
	end
end



