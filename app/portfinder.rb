#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require 'thread'
require 'thwait'
require 'savon'
require 'json'
require 'webrick'
require 'webrick/websocket'
require_relative '../core/config.rb'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/utils.rb'
require_relative '../core/threadpusher.rb'
require_relative '../core/db_billing.rb'
require 'allocation_stats'

class PortFinder

	attr_accessor :options

	TARGET_INSERTED = 1
	TARGET_PUSHED = 2

	def initialize
		#
		# start
		#
		$dbglevel = 0
		@dbbill = DbBilling.new
		@queue = Array.new
		@sem = Mutex.new
		@utils = Utils.new
		@utils.addPersistentConnection('192.168.1.1',22)

		@p = ThreadPusher.new()
		@url = 'http://billing:8080/bgbilling/api/ru.newman.bgbilling.service/Svtk?wsdl'
		p "Billing url for push: #{@url}"
		@client = Savon.client(wsdl: @url)	
		@options = { :maxthreads => 1, :workdb => false , :wsdl => false  }
	end

	def optionsParse

		OptionParser.new do |opts|
			opts.banner = "Usage: example.rb [options]"

			opts.on("-m", "--max-threads MAX", "Max threads") do |v|
				@options[:maxthreads] = v.to_i
			end
			opts.on("-c", "--export-db", "Check sessions in database.") do |v|
				@options[:exportdb] = true
			end
			opts.on_tail("-h", "--help", "Show this message") do
				puts opts
				exit
			end
		end.parse!

	end 

	#
	# pushing into database and try send to billing
	#
	def pushTarget(t,db,wsdl)
		
		if db
			@dbbill.transaction do 
				pwarn "Pushing in db cid:#{t['cid']}, switch:#{t['host']}, port: #{t['port']}, mac: #{t['mac']}, vlan:#{t['vlan']}",0
				@dbbill.pushClient(t['cid'].to_i,t['mac'],t['host'],t['port'],t['vlan'],TARGET_INSERTED)
			end
		end
		if wsdl
			pwarn "Sending WSDL Call cid:#{t['cid']}, switch:#{t['host']}, port: #{t['port']}, mac: #{t['mac']}, vlan: #{t['vlan']}",0
			pfile "Sending WSDL Call cid:#{t['cid']}, switch:#{t['host']}, port: #{t['port']}, mac: #{t['mac']}, vlan: #{t['vlan']}\n","cidmac_success.log"
			response = @client.call(:generate_object_port, :message => { arg0: t['cid'], arg1: t['host'] ,arg2:t['port'], arg3: "#{t['vlan']}A" })	
			result = response.xpath("//ns2:GenerateObjectPortResponse/return").first.inner_text 
			str = result.split(":")
			if str[0] == "0" || str[0] == "1" || str[0] == "2"
				pinfo "Result code: #{str[0]} message: #{str[1]}",0
				@dbbill.setClientStatus(t['cid'],t['mac'],TARGET_PUSHED)
			else
				pdbg "Result code: #{str[0]} message: #{str[1]}",0
				pfile "Error cid:#{t['cid']}, switch:#{t['host']}, port: #{t['port']}, mac: #{t['mac']}, vlan: #{t['vlan']} code:#{str[0]} msg:#{str[1]}\n","cidmac_error.log"
			end
		end
	end

	def searchWorkerThread
		t = Thread.new() do 
			loop do
			#	stats = AllocationStats.trace do
			#		p "do"
					searchWorker()
			#	end
			#	puts $stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).to_text
			end
		end
	end

	#
	# search mac from queue and push it
	#
	def searchWorker
		#
		# check queue
		#
		wqueue = nil
		size = 0
		@sem.synchronize do
			size = @queue.length
			wqueue = @queue.clone
			@queue = []
		end
		if size == 0 
			sleep(10)
			return
		end
		#stats = AllocationStats.trace
		
		
		#
		# DataWorker
		#
		pwarn "Wakeuped and WorkQueue size = #{wqueue.size}!",0
		@p.setThreadDataWorker() do |thread|
			#p response
			next if thread['row'] == nil
			t = thread['row']
			# getting last two octect of ip
			m = t['host'].match(/192\.168\.([0-9]+)\.([0-9]+)/)
			if m != nil
				# leading zero and format string
				host = "#{m[1].rjust(3,'0')}-#{m[2].rjust(3,'0')}"
				# port
				if t['port'].count('/') != 0
					port = t['port']
				else
					port = "#{t['port'].rjust(2,'0')}"
				end
				t['host'] = host
				t['port'] = port
				pushTarget(t,true,t['wsdl'])
			end
		end
		#
		# Thread searchSwitchPortByMac
		#
		@p.pushThreads(@options[:maxthreads],wqueue) do |row|
			#statz = AllocationStats.trace
			# Получаем запись по сид+мак и смотрим время обновления.
			z = @dbbill.getClientByCidMac(row['cid'],row['mac'])
			# Если записи нету z будет nil, если порт для мака будет найден то время обновлено.
			if z != nil
				subsize = Time.now.to_i - z['updatetime'].to_i
				gpon = true if z['port'].index(':') != nil
				
				# если была произведена запись в базу и не прошла неделя 
				# просто прибавляем количество попыток
				if subsize < 604800 && !gpon
					pinfo "Mac=#{row['mac']} cid=#{row['cid']} is very early time live, #{subsize}s < (604800)week.",0
					@dbbill.increaseClientAttempts(row['cid'],row['mac'])
					next
				end
				if subsize < 172800 && gpon
					pinfo "Mac=#{row['mac']} cid=#{row['cid']} is very early time live, #{subsize}s < (172800)2day.",0
					@dbbill.increaseClientAttempts(row['cid'],row['mac'])
					next
				end
			end

			row['wsdl'] = true
			#pfile "search #{row['mac']}\n","defunc.log"
			r = nil
			r = @utils.searchSwitchPortByMac(row['mac'])
				#cmdout=`ps -ax| grep defunc`
			#pfile "output #{cmdout}","defunc.log"
			row['host'] = r['host']
			row['port'] = r['absolute_port']
			row['vlan'] = r['vlan']
			if r['status'] == 'ok'
				pdbg "SearchPortByMac success mac:#{row['mac']} switch:#{r['host']}, port: #{r['port']}, vlan:#{r['vlan']} ,mode:#{r['mode']}",0
				Thread.current["row"] = row
			elsif r['status'] == 'ok_trunk' 
				if !r['desc'].match(/^(N-AP-|AP-)/).nil? && r['vlan'].to_i == 406 
					pdbg "SearchPortByMac success, but TRUNK mode and AP checked mac:#{row['mac']} switch:#{r['host']}, port: #{r['port']}, vlan:#{r['vlan']} ,mode:#{r['mode']} ,desc:#{r['desc']} ",0
					Thread.current["row"] = row
				else
					pdbg "SearchPortByMac success, but TRUNK mode mac:#{row['mac']} switch:#{r['host']}, port: #{r['port']}, vlan:#{r['vlan']} ,mode:#{r['mode']} ,desc:#{r['desc']} ",0
					pfile "SearchPortByMac success, but TRUNK mode mac:#{row['mac']} switch:#{r['host']}, port: #{r['port']}, vlan:#{r['vlan']} ,mode:#{r['mode']} ,desc:#{r['desc']}\n","trunkfails.log"
					# если найден транк для мака то отключаем wsdl чтобы не отсылался на биллинг
					# и делаем запись в бд что мы уже знаем этот мак.
					row['wsdl'] = false
					Thread.current["row"] = row
				end
			elsif r['status'] == 'portmode_fail'
				# fix for gpon dynamic port add
				if r['port'].match("epon[0-9]+/[0-9]+:[0-9]+")
					r['mode'] = 'access'
					pdbg "SearchPortByMac success, but port EPON without mode, mac:#{row['mac']} switch:#{r['host']}, port: #{r['port']}, vlan:#{r['vlan']} ,mode:#{r['mode']}",0
					Thread.current["row"] = row
				else
					pdbg "SearchPortByMac notfound port, mac:#{row['mac']} cid=#{row['cid']}",0
				end
			else
				pdbg "SearchPortByMac notfound port, mac:#{row['mac']} cid=#{row['cid']}",0
			end
			#statz.stop
			#puts "Insearch"
			#puts statz.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).to_text
			GC.start
		end
		GC.start
		pdbg "Thread ready.",0
		#stats.stop
		#puts stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).to_text
	end

	def exportDatabase
		#
		# working with sessions from db
		#
		if @options[:wsdl]
			pinfo "Sending database mac in state (1) by wsdl.",0
			@dbbill.transaction do
				list = @dbbill.getClientsFoundNotReady()
				pwarn "Not ready macs count = #{list.length}"	
				q = ThreadPusher.new()
				q.pushThreads(1,list) do |row|
					begin
						pushWsdlOrDb(row,false,@options[:wsdl])
					rescue => e
						pexcept e
					end
				end
			end
		end

		pinfo "Searching macs by database.",0
		@dbbill.transaction do
			@sem.synchronize do
				@queue = @dbbill.getClientsNotFound()
			end
		end
		searchWorker()
	end

	def httpWorker
		server = WEBrick::HTTPServer.new :Port => 8081
		server.mount "/", WEBrick::HTTPServlet::FileHandler, "#{$rootpath}/www"
		server.mount_proc('/pushqueue'){ |req, resp|
			resp['Content-Type'] = 'text/html'
			params = req.query()
			host = nil
			if params.has_key?('cid') && params.has_key?('mac')
				if params['cid'].match(/[0-9]{1,5}/) != nil && params['mac'].match(/[a-fA-F0-9:]{17}/) != nil
					case params['cid'].to_i
					when 20800
						pdbg "Discard #{params['cid']} and #{params['mac']}"
						resp.body = JSON.generate({ "status"=> 'discard' })
					else
						o = {'mac' => params['mac'].downcase().delete("-.:").scan(/../).join(":"), 'cid' => params['cid'], 'host' => nil, 'port' => nil }
						#if o['mac'] == '5c:f4:ab:cf:18:29'
							ok = true
							@sem.synchronize do
								@queue.each do |x|
									if x['mac'] == o['mac']	
									#if '5c:f4:ab:cf:18:29' == o['mac']
										ok = false
									end
								end
								@queue.push(o) if ok
							end
							#
							if ok
								pdbg "Pushed in queue cid=#{o['cid']} mac=#{o['mac']} InQueue size = #{@queue.size} ",0
							else
								pdbg "Already exists in queue cid=#{o['cid']} mac=#{o['mac']}",0
							end
							#
							resp.body = JSON.generate({ "status"=> 'pushed inqueue' })
						#end
					end
				else
					pdbg "Discard #{params['cid']} and #{params['mac']}"
					resp.body = JSON.generate({ "status"=> 'discard' })
				end
			end
		}
		trap('INT') { server.stop }
		server.start
	end

	def start
		optionsParse()
		if @options[:exportdb]
			exportDatabase()	
			p "Export ended."
		end
		searchWorkerThread()
		httpWorker()
		
	end
end

p GC.start
p GC.enable

PortFinder.new.start()
