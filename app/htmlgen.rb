#!/usr/local/bin/ruby
# encoding: utf-8
require_relative '../core/config.rb'
require_relative '../core/db.rb'
require_relative '../core/erbcontext.rb'
require_relative '../core/debug.rb'
require 'optparse'

class GenMap
		
	attr_accessor :forcemap
	attr_accessor :buildhtml
	attr_accessor :test
	
	def initialize()
		@forcemap = false
		@buildhtml = false
		@test = false
	end

	def run()
		@rootmac = "3c:8a:b0:10:13:41"
		#@rootmac = "00:22:90:49:6a:80"
		#@rootmac = "00:17:e0:58:d3:41"
		@names = Hash.new
		$warrings = Hash.new
		$nouplink = Array.new
		
		@db = Db.new
		# clear all uplinks for reset linking
		@db.clearAllHostUplinks() if @buildhtml
		# get collected
		@arp,@hosts,@names = @db.getHostsAndMacs('100,121')
		$arp = @arp
		$hosts = @hosts
		$names = @names

		if @test
			root = nil
			@db.transaction do
				root = @db.getMapHash(-1)
				#p root
			end
			@selftest = @hosts.keys
			print_tree({"root"=>root},0)
			exit
		end

		pinfo "Makeing map.",0
		#p @hosts[@rootmac]

		root = find_neighbor(@rootmac,nil)
		#p root

		print "-------------------------------------------\n"
		@selftest = @hosts.keys
		print_tree({"root"=>root},0)

		@db.deleteAllUpdateHosts()
		print "-------------------------------------------\n"
		print " Hosts not connected count=#{@selftest.count}.(selftest)\n"
		print "-------------------------------------------\n"
		@selftest.each {|mac| 
			print "* [#{mac}] (#{(@arp.has_key?(mac) ? @arp[mac] : "")}) #{(@names.has_key?(mac) ? @names[mac] : "")} \n\r"
			@db.insertUpdateHost(@arp[mac])
			#if @arp.has_key?(mac)
			#	pfile "#{@arp[mac]}","map_notconnect.log"
			#end
		#	print "#{(@arp.has_key?(mac) ? @arp[mac] : "")}\n"
		}
		print "-------------------------------------------\n"
		print " No uplink found:\n"
		print "-------------------------------------------\n"
		$nouplink.each do |mac| 
			print "* [#{mac}] (#{(@arp.has_key?(mac) ? @arp[mac] : "")}) #{(@names.has_key?(mac) ? @names[mac] : "")} \n\r"
			if @arp.has_key?(mac)
				@db.insertUpdateHost(@arp[mac])
			end
		end
		print "-------------------------------------------\n"
		print " Not mac-collected hosts	\n"
		print "-------------------------------------------\n"
		nomacs = @db.getHostsNoRetreivedMacs() 
		nomacs.each do |row|
			print "* [#{row['mac']}] (#{row['host']}) \n\r"
			@db.insertUpdateHost(row['host'])
		end

		exit if !@buildhtml 
		
		gen_template({"root"=>root})

		@dt = Db.new
		pdbg "Write map links into DB.",0
		@dt.transaction do
			@dt.putMapHash(root,-1,@arp)
		end
		pinfo "Try read map from DB.",0
		toor = nil
		@dt.transaction do
			toor = @dt.getMapHash(-1)
		end
		#p toor
	end

	def gen_template(root)
		@html = File.open("#{$rootpath}/www/tree.html", "w")
		r = (ERBContext.new({ "param" => root })).render("#{$rootpath}/template/tree.erb")
		#r = r.delete("\t\n")
		@html.write(r)
	end

	def make_level(level,size,sym)
		i = 0
		color = 1
		strlvl = ""
		while i != level do
			strsym = sym * size
			strlvl = strlvl.concat("\e[9#{color}m#{strsym}")
			i = i + 1
			#
			if color == 7
				color = 1
			else
				color = color + 1
			end
		end
		strlvl.concat("\e[0m")
	end

	def print_tree(node,level)
		#space = " " * level * 2
		space = make_level(level,1,"| ")
		node.keys.each { |port|
			if node[port] != 'UPLINK' 
				color = ""
				reset = ""
				# do not show other ports
				next if node[port] == nil
				# if show other port
				#if node[port] == nil
				#	print "#{space}#{color}L{#{port}}#{reset}\n\r"
				#	next
				#end
				mac = node[port].keys[0]
				@selftest.delete(mac)
				# подсвечивать ли мак при проблемах
				if $warrings.has_key?(mac)	
					color = "\e[31;1m" 
	       				reset = "\e[0m" 
				else
					color = ""
					reset = ""
				end
				print "#{space}#{color}L{#{port}}[#{mac}] (#{(@arp.has_key?(mac) ? @arp[mac] : "")}) #{(@names.has_key?(mac) ? @names[mac] : "")}#{reset}\n\r"
				#print "#{space}L{#{port}}[#{mac}] (#{(@arp.has_key?(mac) ? @arp[mac] : "")}) #{(@names.has_key?(mac) ? @names[mac] : "")}\n\r"
				if $warrings.has_key?(mac)
					$warrings[mac].each do |msg|
						# Выводим сообщение.
						color = "\e[#{msg[:color]};1m" 
						print "#{space}#{color}[!] #{msg['message']}#{reset}\n\r"
						# Проверяем есть ли список для этого коммутатора.
						if msg.has_key?("macs")
							msg['macs'].each do |x|
								print "#{space}#{color}[!] #{x} (#{(@arp.has_key?(x) ? @arp[x] : "")}) #{reset}\n\r"
							end
						end
					end
				end
				print_tree(node[port][mac],(level+1))
			else
				print "#{space}L{#{port}} uplink?\n"
			end
		}
	end

	def is_neighbor(callmac,upmac,macs)
		
		notfound = macs.clone
		upport=nil
		neighbor=true
		success = 0
		macslength = (macs != nil) ? macs.length : 0 ;
	
		if @hosts.has_key?(callmac)
			
			@hosts[callmac].each { | port, port_macs |
				# check if upmac present on port
				if port_macs.index(@rootmac) != nil
					# Находим аплинковый порт 
					upport=port
					neighbor=true
					# Проверяем что на аплинковом порту нету маков 
					# которые должны находиться за коммутатором
					macs.each { | vmac  |
						if port_macs.index(vmac)
							# Если хоть один мак который должен быть ЗА коммутатором 
							# находиться на аплинковом порту значит это не наш ближайший сосед.
							neighbor=false
							break
						end
					}
					break if neighbor == false
				else
					# Если порт не аплинковый проверяем на нём соответствия маков.
					# Т.е считаем маки устройств за портами.
					macs.each { | vmac |
						if port_macs.index(vmac)
							success = success + 1
							notfound.delete(vmac)
						end
					}
				end
			}
		else
			neighbor = false
		end
		
		#p "Success: #{success} Macs.length: #{macslength}"
		
		# Условия:
		# 1.Если наден аплинк и на нём отсутвует маки которые должны быть за коммутатором
		# 2.Если маки которые должнбыть ЗА соответсуют по количеству на предыдущем коммутаторе.
		# 3. Если
		# 	3.1 Мак джунипера найден т.е найден аплинк порт.
		# 	или
		# 	3.2 Если коммутатор имеет ноль маков тоесть является не опрашиваемым.
		status = neighbor && ( success == macslength ) && ( upport != nil || @hosts[callmac].length == 0 )
		# Если мы прошли проверку на соседа то +1 к весу.
		# Это для того чтобы быть тяжеле тех кто не прошол.
		weight = ( neighbor ) ? success+1 : success
		return { "status" => status, "upport" => upport , "weight" => weight ,"mac" => callmac, "notfound" => notfound }

	end

	def find_neighbor(callmac,upport)
		
		tree = Hash.new
		tree[callmac] = Hash.new			

		# Выходим с пустым деревом если нарвались на неопрашиваемый коммутатор
		return tree if @hosts[callmac] == nil

		praw "Iterate ports of mac #{callmac}"
		@hosts[callmac].each { |port, port_macs|
			if port != upport
				
				praw "Check port #{port}"
				praw "Mac of ports, count =#{port_macs.length}"
				#p port_macs

				plist = Hash.new
				status = false

				port_macs.each { | mac |
					last = port_macs.dup
					last.delete(mac)
					# Проверяем сосед или нет
					r = is_neighbor(mac,callmac,last)
					# Запоминаем приоретет.
					if @forcemap
						weight = r['weight']
						plist[weight] = r
					end
					praw r
					# Проверяем найден ли сосед.
					status = r['status']
					if status
						tree[callmac][port] = find_neighbor(mac,r['upport'])
						break
					end
				}
				if !status #&& port_macs.length > 1
					pushInfo(callmac,{ :color => 91, "message" => "Not found absolute neighbor, port: #{port}" })
					# Сохраняем проблемный мак=порт
					if @forcemap
						praw "Forced for port #{port}"
						#p plist
						# Получаем лутший по весу совпадения маков коммутатор
						best = (plist.keys.sort { |x,y| y <=> x })[0]
						mac = plist[best]['mac']
						myupport = plist[best]['upport']
						# Сохраняем информацию о месте проблемы
						# Если у мака нету не каких маков и портов то он - не опрашиваемый.
						if ( !@hosts.has_key?(mac) || @hosts[mac].length == 0  )
							pinfo "Not collectable"
							# Ложим в массив вывода мак, и информацию о нем.
							pushInfo(mac,{ :color => "95",  "message" => "No retrived mac table hosts" })
							# Строим ево дерево и устанавливаем для текущего порта.
							tree[callmac][port] = find_neighbor(mac,myupport)
						# Мак опрашиваемый и аплинк есть.
						elsif myupport != nil 
							pinfo "Collectable and uplink has."
							# Ложим в массив вывода мак, и информацию о нем.
							pushInfo(mac,{ :color => "91", "message" => "Switch added by weight, uplink = #{myupport}" , "macs" => plist[best]['notfound'] })
							# Строим ево дерево и устанавливаем для текущего порта.
							tree[callmac][port] = find_neighbor(mac,myupport)
						else
						# Мак опрашваемый и но аплинк не найден.
							pinfo "Collectable and uplink not has."
							$nouplink.push(mac)
							# Суда напихиваем массив коммутаторов без аплинка.
							#$warrings[mac] = { "port" => port , "notfound" => plist[best]['notfound'] }
						end
						#exit
					end
				end
			else 
				# Устанавливаем метку аплинка.
				tree[callmac][port] = 'UPLINK'
			end
		}
		return tree
	end

	def pushInfo(mac,msg)
		$warrings[mac] = Array.new if !$warrings[mac] != nil
		$warrings[mac].push(msg)
	end


end

# options default

#options = { :buildhtml => false , :forcemap => false }

$dbglevel = 0
obj = GenMap.new

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"
	
	opts.on("-f", "--forcemap", "Force build map with wrong or little data.") do |v|
		obj.forcemap = v
	end
	opts.on("-b", "--buildhtml", "Build html static page map.") do |v|
		obj.buildhtml = v
	end
	opts.on("-d", "--debug", "Debug info.") do |v|
		$dbglevel = 20
	end
	opts.on("-t", "--test", "Test database map.") do |v|
		obj.test = v
	end
	opts.on_tail("-h", "--help", "Help") do
		puts opts
		exit
	end
end.parse!

obj.run()
