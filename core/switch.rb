#!/usr/bin/ruby
require_relative "config.rb"
require_relative "patterns.rb"
require_relative "protocols.rb"


class Switch < Protocols

	# getMacAddressByVlan
	attr_accessor :mactable
	# getConfiguration
	attr_accessor :curiface
	attr_accessor :curvlans
	attr_accessor :curmode
	attr_accessor :list
	attr_accessor :trunknames
	attr_accessor :hostname
	# setBroadcastStorm
	attr_accessor :broadcastLimitAccess
	attr_accessor :broadcastLimitTrunk
	# login
	attr_accessor :username
	attr_accessor :password
	attr_accessor :password_a
	attr_accessor :enablePassword
	# version
	attr_accessor :version
	attr_accessor :skipver
	attr_accessor :vendor
	attr_accessor :revision
	attr_accessor :portsnum
	attr_accessor :vobject
	attr_accessor :myclass
	# 
	attr_accessor :me
	attr_accessor :current_account
	attr_accessor :only_password
	#

	attr_accessor :init_screen
	attr_accessor :index_screen
	
	def initialize(mexpect)
		@me = mexpect
		@list = Hash.new
		@hostname = nil
		@backupSSHAccount = $backupSSHAccount
		@enablePassword = $enablePassword
		# version	
		@vobject = {}
		@myclass = nil
		@version = "unknow"
		@skipver = false
		@portsnum = nil
		@revision = nil
		@vendor = nil
		# account
		@accounts = $accounts 
		@current_account = nil
		@only_password = false
		# templates	
		templates()
		@me.switch = self
		@me.protocol_clear()
		protocols()
	end

	def copy_all_public(obj)
		obj.instance_variables.each { |k|
			self.instance_variable_set(k,obj.instance_variable_get(k))
		}
	end
	
	def send(msg)
		@me.send(msg)
	end
	
	#
	# protocols
	#
	
	def protocols
		pwarn "Setting default protocols"
	
		self.init_screen = [
			"\x1b[?1;0c\x1b[52;3R",
			"\x1b[52;1R",
			"\x1b[1;1R",
			"\x1b[1;204R",
			"\x1b[1;4R",
			"\x1b[1;204R",
			"\x1b[1;205R",
			"\x1b[2;2R",
			"\x1b[1;1R",
			"\x1b[5;1R",
			"\x1b[52;1R"
		]
		self.index_screen = 0;
		
		@me.protocol_string("terminal_mikrotik") do |slf,b|
			#pinfo "Call terminal_mikrotik"
			# delete e[m
			b.gsub!(/\e\[[0-9]{0,}m/,"")
			b.gsub!(/\e\[[0-9]{0,};[0-9]{0,}m/,"")
			# get current cursor position
			x=b.scan("\e\[6n")
			x.each do |v|
				if self.index_screen < self.init_screen.size
					slf = self
					#p slf.init_screen
					pwarn "Send escape #{slf.init_screen[slf.index_screen]}"
					self.send(slf.init_screen[slf.index_screen])	
					slf.index_screen = slf.index_screen + 1
				end
			end
			b
		end
		
		@me.protocol_string("terminal_qtech29") do |slf,b|
			#pinfo "Call terminal handler qtech29"
			b.gsub!(/(\e\[74D\e\[K)/,"")
			b.gsub!(/([^\n\r]{0,}\e\[73D\e\[K)/,"")
			b
		end
		@me.protocol_binary("telnet",&self.method(:proto_telnet_options_neogotiate))
		@me.protocol_string("terminal_escape_b",&self.method(:proto_option_b))
	end

	#
	# templates
	#
	def templates
		slf = self
	end

	def getAccountHost(ca)
		r = nil
		@accounts.each do |x|
			next if x == ca
			next if !x.has_key?("hosts")
			x['hosts'].each	do |z|
				next if z['host'] != @me.host
				if z.has_key?('port')
					next if z['port'].to_s == @me.port
					r = x
					break
				else
					r = x
				end
			end
		end
		r
	end

	def getAccountAll(ca)
		r = nil
		idx = @accounts.index(ca).to_i
		#p @accounts.length-1
		for i in idx..@accounts.length-1
			x = @accounts[i]
			#p i
			next if x.has_key?("hosts")
			next if x == ca
			r = x
			break
		end
		#p r
		r
	end

	def getAccount
		r = getAccountHost(@current_account)
		#p "getAccountHost() - #{r}"	
		if r != nil
			@current_account = r
			return r
		end
		r = getAccountAll(@current_account)
		@current_account = r
		#p "getAccountAll - #{r}"
		r 
	end

	#
	# WARRING: Login called from instance Switch without child.
	# incorrect|invalid|denied|bad|fail|error
	def login
		slf = self
		connected = true	
		
		@me.templates("passive_osdetect") do 
			#
			# Passive OS fingerversion
			#
	
			block = Proc.new do |x,e| 
				slf.vobject = e
				slf.version = e['version'] if e.has_key?('version')
				slf.vendor = e['vendor'] if e.has_key?('vendor')
				slf.portsnum = e['portsnum'] if e.has_key?('portsnum')
				slf.myclass = slf.vobject['_myclass'] if slf.vobject.has_key?('_myclass')
				if e.has_key?("block")
					e['block'].call(slf,x,e)
				end
			end

			Patterns.space.each do |x|
				if x.has_key?("_pattern") && x.has_key?("_banner")
					expect(x['_pattern'],x,&block) 
				end
			end

			# DGS-1100
			#expect(/DGS-1100-([0-9]+)/) do |portsnum|
			#	pinfo "Model: DGS1100 Ports count:#{portsnum[1]}"
			#	slf.version = "dgs1100"
			#	slf.vendor = "dlink"
			#	slf.portsnum = portsnum[1].to_i
			#end
		end
		#wait("Escape")
		#@me.send("z\r")
		#exit
		@me.each("passive_osdetect") do
			expect(/Last login: /i) do
				pinfo "Last login skip"
			end
			# eltex fix
			expect(/Password is about to expire/i) do
				pinfo "Password is about expire"
			end
			expect(/(incorrect|invalid|denied|bad|fail|error)/i) do
				connected = false		
			end
			expect(/(login|user name|username)/i) do 
				r = slf.getAccount()
				if r == nil 
					pwarn "Unknow account for this device."
					connected = false		
					slf.me.close()
					break
				end
				pinfo "Found account #{slf.me.host} #{slf.current_account}"
				send("#{slf.current_account['login']}\r")
			end
			expect(/password/i) do
				if slf.current_account == nil || slf.only_password
					slf.getAccount() 
					slf.only_password = true
				end
				if slf.current_account == nil 
					pwarn "Unknow account for this device."
					connected = false		
					slf.me.close()
					break
				end
				send("#{slf.current_account['password']}\r")
			end
			expect(/(close|unable|refused|timed out)/i) do
				connected = false
			end
			expect(/Terminal type?/i) do
				pinfo "Confirm terminal type."
				send("\n")
			end
			# Prompt
			expect(/(#|%|>|Enter your selection)/) do
				connected = true
				pinfo "Detected prompt (login/passive version)"
				break
				# Warring if not place break, cycle not exited
			end
			# SSH
			expect(/Are you sure you want to continue connecting \(yes\/no\)?/) do
				pinfo "SSH Key confirmation."
				send("yes\n")	
			end
		end
		if @me.timeout
			#
			# timeout kill cli
			#
			pdbg "Recving timeouted, close connection"
			@me.close()
			connected = false
		end			
		#
		# wait process exit status only for telnet
		#
		@me.checkClose?() if !connected
		return connected
	end

	def checkInteractiveVersion
		slf = self

		return @version if slf.vobject['_next'] == 'skip'
		
		action = slf.vendor 
		action = slf.vobject['action'] if slf.vobject.has_key?('action')

		if Patterns.actions.has_key?(action)
			f = Patterns.actions[action]
		else
			f = Patterns.actions["0"]
		end
		if f.instance_of?(String)
			send(f)	
		else
			f.call(slf)
		end
		#
		# show version
		#
		@me.each do
			block = Proc.new do |x,e| 
				slf.version = e['version'] if e.has_key?('version')
				slf.vendor = e['vendor'] if e.has_key?('vendor')
				slf.portsnum = e['portsnum'] if e.has_key?('portsnum')
				if e.has_key?("block")
					e['block'].call(slf,x,e)
				end
				if e.has_key?('_myclass') 
					if e['_myclass'].instance_of?(String)
						slf.myclass = e['_myclass'] 
					elsif e['_myclass'].instance_of?(Array)
						found = nil
						#
						# check array versions by this 
						#
						e['_myclass'].each do |x|
							#p "Iterate_myclass array #{x}"
							x.each do |k,v|
								next if k.start_with?("_")
								#p "Check defined #{k}"
								if slf.instance_variable_defined?("@#{k}")
									#p "Check equal #{slf.instance_variable_get("@#{k}")} == #{v}" 
									if slf.instance_variable_get("@#{k}") == v
										found = x
									else
										found = nil
										break
									end
								else
								# if property not setted in class, break
									found = nil
									break
								end
							end
							#
							# if in hash all properties equal found != nil
							#
							if found != nil
								#p "Found = #{found}"
								slf.myclass = found['_myclass']
							end
						end
						#
					end
				end
			end

			if slf.vobject.has_key?("_next") 
				if slf.vobject['_next'].instance_of?(Array)
					# iterate names in _next
					slf.vobject['_next'].each do |t|
						# found patterns by name
						Patterns.space.each do |x|
							if t == x['_name']
								#p slf.vobject
								#p Patterns.interactive
								expect(x['_pattern'],x,&block) 
							end
						end
					end
				end
			else
				Patterns.space.each do |x|
					# add pattern not banner and not notdefault
					if x.has_key?("_pattern") && !x.has_key?("_notdefault") && !x.has_key?("_banner")
						expect(x['_pattern'],x,&block) 
					end
				end
			end
		end
		#p "Your class is #{slf.myclass}"
		@version
	end

	def isPonPort(port)
		# by default for switches false, beacause switch not have virtual epon ports
		return false
	end

	def getAbsolutePort(port)
		return port
	end

	def enableMode()

	end

	def disableMode()

	end

	def setSeverity()

	end

	def checkPingPong()

	end

	def expand_range(range)
		pinfo "Expand range: #{range}"
		rh = Array.new
		r = range.split(",")
		r.each do |x|
			a = x.split("-")
			#signle port
			if a.count == 1
				rh.push(a[0].to_s)
			#range
			else
				i = a[0].to_i	# from
				e = a[1].to_i	# end
				while i <= e do
					rh.push(i.to_s)
					i = i + 1
				end
			end
		end
		pwarn "Expanded:#{rh}"
		rh
	end

	def getPortsStatus()
	
	end
	
	def getPortsDDM()
		nil
	end

	def setSnmpSettings

	end

	def setUnconfiguredAccess(nports=nil)

		# check for dlink unconfigured ports
		if nports != nil
			for i in 1..nports
				pwarn "Checkin port present #{i}"
				if !self.list['ports'].has_key?(i.to_s)
					pinfo "Creating port #{i}"
					self.list['ports'][i.to_s] = Hash.new
				end
			end	
		end

		self.list['ports'].each do |p,opts|
			if !opts.has_key?("mode")
				self.list['ports'][p]['mode'] = "access"
				self.list['ports'][p]['unconfigured'] = "yes"
			end
		
			if !opts.has_key?('untagged')
				self.list['ports'][p]['untagged'] = ["1"]
			end
		
			if !opts.has_key?('tagged')
				self.list['ports'][p]['tagged'] = []
			end
		end
		self.list
	end

	def macToNormal(mac)
		mac.downcase().delete("-.:").scan(/../).join(":")
	end
	def macToCisco(mac)
		mac.downcase().delete("-.:").scan(/..../).join(".")
	end
	def macToDash(mac)
		mac.downcase().delete("-.:").scan(/../).join("-")
	end

	def typeLongToShort(port)
		@ifacenames[port]
	end
	def typeShortToLong(port)
		@ifacenames.key(port)
	end

	def setSnmpTrapHost(host,community)
	end
	def removeSnmpTrapHost(host,community)
	end

	def exit()
		# initiate recving anything (.*) on stream for closed process
		# when recv raise exception, call checkExitStatus in recv call that exited zombie
		pinfo "Exit() - recving any and wait close."
		@me.each do
			expect(/.*/) do 
			end
		end
		Debug.closeAll()
	end

	def wait(regex)
		slf = self
		@me.each do
			expect(regex) do 
				pinfo "Wait"
				break
			end
		end
	end
end

