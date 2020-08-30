
class SE100 < Switch
	
	def initialize(mexp)
		super(mexp)
	end

	def templates
		super();
		# set templates
		#
		@me.templates("more") do
			expect(/--\(more\)--/) do
				pinfo "More"
				send(" ")
			end
		end
	end
	def getConfiguration
		slf = self
		
		# getting config
		#
		@me.send("show configuration\n")
		@me.each("more") do
			expect(/hostname (.*?)\n/) do |x|
				pinfo "Hostname: #{x[1]}"
				slf.set_option("global","hostname",nil, x[1].delete('"'))
			end
			expect(/#/) do
				pinfo "Detected Prompt"
				break
			end
		end	
	end

	def enableMode()
	end
	def ConfigurationMode
	
	end
	def setBroadcastStorm(port,speed)
	end
	def getMacAddressByVlan(vlan)
		[]
	end
	def writeCfg
	end
	def copyCfgToTftp(host,dest)
		slf = self
		@me.send("copy redback.cfg tftp://#{host}#{dest}\n")
		wait("#")
	end
	def ping(host)
	end
	def exit()
		@me.send("exit\n")	
		super
	end
end



