class  MikrotikTemplate < Switch

	attr_accessor :vlaniface
		
	def initialize(mexp)
		super(mexp)
		@trunknames = [ "gi1/0/1", "gi1/0/2", "gi1/0/3", "gi1/0/4" ]
		@broadcastLimitAccess = 32
		@broadcastLimitTrunk = 900
		@ifacenames = { 
		}
		@vlaniface = nil
	end
	
	
	def protocols
		super
	end

	def templates()
		# set templates
		@me.templates("more") do 
			expect(/<space>/) do
				pinfo "More"
				send(" ")
			end
		end
	end

	def getAbsolutePort(port)
		if x = port.match(/[a-z]+[0-9]+\/[0-9]+\/([0-9]+)/)
			return x[1]
		end
		return port
	end

	def getConfiguration
		slf = self
		# getting config
		#
		@me.send("/export\r")
		@me.each() do
			expect(/system identity\n/) do |x|
				each("more") do 
					expect(/set name=(.*?)\n/) do |x|
						pinfo "Hostname: #{x[1]}"
						slf.set_option("global","hostname",nil, x[1].delete('"'))
						break
					end
				end
			end
			#expect(/interface ethernet\n/) do |x|
			#	each("more") do 
			#		expect(/set \[ find default-name=(.*?) \]\s+(name=.*?)?/) do |x|
			#			p x	
			#		end
			#	end
			#end

			expect(/\] >/) do
				pinfo "Detected prompt"
				break
			end
		end
	end
	
	def getPortsStatus()
		slf = self
		self.list['ports']
	end
	def getPortError(port)
		slf = self

		self.list['ports'][port]
	end
	def clearPortCounter(port)
	end
	def setPortState(port,state)
	end
	def getMacAddressByVlan(vlan)
		vi = self.getInterfaceVlan()
		r = self.getMacAddress('vlan',vlan)
		return r
	end
	def getMacAddressByPort(port)
		vi = self.getInterfaceVlan()
		r = self.getMacAddress('port',port)
		return r
	end
	def getPortByMacAddress(addr)
		vi = self.getInterfaceVlan()
		r = self.getMacAddress('mac',addr)
		return r
	end
	def getMacAddressAll()
		vi = self.getInterfaceVlan()
		r = self.getMacAddress('all','all')
		return r
	end
	def getMacAddress(groupkey,value)
		slf = self
		slf.mactable = Hash.new
		@me.send("/interface bridge host print without-paging \r")
		wait("MAC-ADDRESS")
		@me.each do
			expect(/[0-9]+\s+[A-Z]+\s+([0-9A-F:]+)\s+([0-9A-Za-z:\-_]+)\s+([0-9A-Za-z:\-_]+)/) do |x|
				lst = Hash.new
				lst['all'] = 'all' if groupkey == 'all'
				lst['mac'] = slf.macToNormal(x[1])
				lst['vlaniface'] = x[2]
				vlaniface = x[2]
				lst['br'] = x[3]
				pinfo "vlaniface=#{vlaniface}"
				if slf.vlaniface.has_key?(vlaniface) 
					lst['vlan'] = slf.vlaniface[vlaniface][:vid].to_i
					lst['port'] = slf.vlaniface[vlaniface][:iface]
					
					pinfo lst
					if lst[groupkey] == value
						pinfo "EQUAL"
						slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
						slf.mactable[lst[groupkey]].push(lst)
					end
				end
			end
			expect(/<space>/) do
				pinfo "More"
				send(" ")
			end
			expect(/\] >/) do
				pinfo "Detected prompt"
				break
			end
		end
		return slf.mactable
	end
	def getInterfaceVlan()
		slf = self
		@me.send("/interface vlan print without-paging \r")
		wait("] >")
		slf.vlaniface = Hash.new
		@me.each do
			expect(/(\s+[0-9]+\s+R)?\s+([0-9A-Za-z:\-_]+)\s+[0-9]+\s+[A-Za-z]+\s+([0-9]+)\s+([A-Za-z0-9:\-_]+)/) do |x|
				vlaniface = x[2]
				vid = x[3]
				iface = x[4]
				pinfo "vname=#{vlaniface} vid=#{vid}"
				slf.vlaniface[vlaniface] = { :vid => vid, :iface => iface }
			end
			expect(/<space>/) do
				pinfo "More"
				send(" ")
			end
			expect(/\] >/) do
				pinfo "Detected prompt"
				break
			end
		end
		#p slf.vlaniface
		return slf.vlaniface
	end
	
	def ConfigurationMode
	end
	def setBroadcastStorm(port,speed)
		slf = self
	end
	def writeCfg
		slf = self
	end
	def copyCfgToTftp(host,dest)
		slf = self
	end
	def ping(host)
	end
	def exit()
		@me.send("/quit\r")
		super
	end
end

