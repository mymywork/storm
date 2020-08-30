require_relative 'templates/cisco_template.rb'

class Cisco6506 < CiscoTemplate
	
	def initialize(mexp)
		super(mexp)
		@trunknames = [ ]
		@broadcastLimitAccess = 1
		@broadcastLimitTrunk = 1
	end

	def getMacAddressByVlan(vlan)
		@me.send("show mac address-table vlan #{vlan}\n")
		self.parseMacAddress('vlan')
	end

	def getPortByMacAddress(addr)
		@me.send("show mac address-table address #{addr}\n")
		self.parseMacAddress('mac')
	end

	def getMacAddressByPort(port)
		@me.send("show mac address-table interface #{port}r\n")
		self.parseMacAddress('port')
	end
	def getMacAddressAll()
		@me.send("show mac address-table\n")
		self.parseMacAddress('all')
	end

	def parseMacAddress(groupkey)
		slf = self
		slf.mactable = Hash.new
		@me.each do
			expect(/ *\s+([0-9]+)\s+([0-9.a-f]+)\s+(dynamic|static)\s+[A-Za-z]+\s+[0-9]+\s+([A-Za-z0-9\\\/]+)\n/) do |x|
				#mac = slf.macToNormal(x[2])
				#vlan = x[1]
				#port = x[4]
				#pinfo "vlan #{vlan} mac #{mac} port = #{port}"
				#slf.mactable[mac] = { :port => port , :vlan => vlan }			
				
				lst = Hash.new
				lst['all'] = 'all'
				lst['mac'] = slf.macToNormal(x[2])
				lst['vlan'] = x[1]
				lst['port'] = x[3]
				pinfo lst
				slf.mactable[lst[groupkey]] = Array.new if !slf.mactable.has_key?(lst[groupkey])
				slf.mactable[lst[groupkey]].push(lst)
			end
			expect(/--More--/) do
				pinfo "More"
				send(" ")
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		return slf.mactable
	end

	def setBroadcastStorm(port,speed)
		slf = self
		@me.send("interface #{port}\n")
		@me.send("storm-control broadcast level #{speed}\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
	def arpResolve(host)
		slf = self
		mac=nil
		@me.send("show arp | include #{host}[ ]")
		@me.each do
			expect(/^Internet\s+([0-9.]+)[\s\t]+[0-9\-]+\s+([a-f0-9.]+)\s+ARPA\s+([A-Za-z0-9\\\/]+)\n/) do |x|
				mac = slf.macToNormal(x[2])
				host = x[1]
				pinfo "Found mac #{mac}"
			end
			expect(/#/) do
				pinfo "Detected prompt"
				break
			end
		end
		mac
	end
end



