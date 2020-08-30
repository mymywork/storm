#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative 'manager.rb'
require_relative 'db.rb'

$loghandle = nil

WRAP = 0
TCP = 1

class Utils

	def initialize
		@db = Db.new
		@persistent = Hash.new
	end

	def addPersistentConnection(host,port)
		pinfo "Adding persistent connection to #{host} service #{port}",0
		#sm = SwitchManager.new(host,port)
		if host == '192.168.1.45'
			sm = SwitchManager.new(host,port) do |mypid,myhost|
				begin
					$loghandle = Debug.openFile("#{$rootpath}/log/#{myhost}.log")
				rescue => x
					p x
				end

			end
		else
			sm = SwitchManager.new(host,port)
		end
		wrk = sm.getContainer()
		pinfo "Reconnected CONTAINER  to #{host} service #{port}",0
		sleep 5
		if wrk == nil
			swport = nil
			pwarn "--> Service port #{port} not connect.",0
			return
		end
		wrk.enableMode()
		@persistent[host] = wrk
		wrk
	end

	def checkPersistentConnection(sw)
		#if sw.me.mode == WRAP
			r = !sw.checkPingPong()
			pinfo "call checkPingPong #{r}",0
			sw.me.close() if r
			return r
		#end
		#return sw.me.checkClose?(Process::WNOHANG)
	end

	def searchSwitchPortByMac(smac)

		mac = smac.downcase().delete("-.:").scan(/../).join(":")
		switch = ['192.168.1.1','192.168.1.2']
		wrk = nil
		swhost = nil
		swport = nil
		swvlan = nil
		newhost = nil
		loopback = Array.new

		pinfo " # Working with mac #{smac}",0
		switch.each do |x|
			swhost = x
			while true
				if loopback.index(swhost) != nil
					pwarn "Loopback detected on host #{swhost}",0
					return { "status" => "loop" }
				end
				loopback.push(swhost)
				portlist = [23,22]
				hostrow = @db.getHost(swhost)
				if hostrow != nil 
					portlist = hostrow['services'].split(",") if hostrow['services'] != ""
				end
				# HACK:sorting ot bolshego k menshimu
				portlist.sort! { |a,b| b.to_i <=> a.to_i }
				portlist.each do |port|
					if swhost == '192.168.1.45' and $loghandle != nil
						#Thread.current["io"] = Hash.new
						#Thread.current["io"]["#{$rootpath}/log/#{swhost}.log"] = $loghandle						
						#p "pre"
						#p Thread.current["io"]
						#Debug.setRedirectToLogging("#{$rootpath}/log/#{swhost}.log")
					end
					pinfo "Search mac on #{swhost} service #{port}",0
					if @persistent.has_key?(swhost)
						pinfo "Host #{swhost} has persistent connection",0
						wrk = @persistent[swhost]	
						r = checkPersistentConnection(wrk)
						pinfo "Persistent process-exited/socket-closed is #{r}",0
						wrk = addPersistentConnection(wrk.me.host,wrk.me.port) if r
					else
						sm = SwitchManager.new(swhost,port)
						wrk = sm.getContainer()
						if wrk == nil
							swport = nil
							pwarn "--> Service port #{port} not connect.",0
							next
						end
						wrk.enableMode()
					end
					
					# get port from mac tables
					mactbl = wrk.getPortByMacAddress(mac)
					# do exit if not persistent
					if swhost == '192.168.1.45' && $loghandle != nil
						#p Thread.current["io"]
						#Thread.current["io"].delete("#{$rootpath}/log/#{swhost}.log")
						#Debug.setRedirectToLogging(false)
					end
					wrk.exit() if !@persistent.has_key?(swhost)
					
					pwarn mactbl
				
					if mactbl.length != 0
						if mactbl[mac].length > 1
							pwarn "--> Mac present more then one port #{mactbl[mac].map {|x| x['port']}.join(", ")}"
						end
						mactbl[mac].each do |i|
							swport = i['port']
							swvlan = i['vlan']
							pinfo "--> Mac found on port #{swport}",0
						end
					else
						swport = nil
						pdbg "--> Mac not found.",0
						break
					end
					# get next switch by database
					newhost = @db.getSwitchOnPort(swhost,swport)
					if newhost == nil
						pwarn "--> Switch on port not found.",0
						break
					end
					swhost = newhost
					break
				end
				break if wrk == nil
				break if swport == nil
				break if newhost == nil
			end
			# Если прошел дальше свитча из листа значит 
			# просто чтото пошло не так
			break if swhost != x 
			# Если же не прошел включаем результат в тру 
			# и пробуем следущий корневой свитч из листа
		end
		if swport != nil
			if wrk.isPonPort(swport)
				pdbg "Found #{swhost} port #{swport} is PON treat as access",0
				return { "status" => "ok" , "host" => swhost, "port" => swport, "vlan" => swvlan, "mode" => 'access', "absolute_port" => wrk.getAbsolutePort(swport) }
			end
			info = @db.getSwitchPortInfo(swhost,swport)
			if info == nil
				pdbg "Port mode lookup failed.",0
				return { "status" => "portmode_fail" , "host" => swhost, "port" => swport, "vlan" => swvlan, "absolute_port" => wrk.getAbsolutePort(swport) }
			end
			if info['mode'] == "access"
				pdbg "Found #{swhost} port #{swport}",0
				return { "status" => "ok" , "host" => swhost, "port" => swport, "vlan" => swvlan, "mode" => info['mode'], "absolute_port" => wrk.getAbsolutePort(swport) }
			else
				pdbg "Found #{swhost} port #{swport} but port mode = #{info['mode']}",0
				return { "status" => "ok_trunk" , "host" => swhost, "port" => swport, "vlan" => swvlan, "mode" => info['mode'], "desc" => info['desc'], "absolute_port" => wrk.getAbsolutePort(swport) }
			end
		else
			pdbg "Port not found.",0
			return { "status" => "notfound" , "host" => swhost, "port" => swport, "absolute_port" => '' }
		end
	end
end
