#!/usr/local/bin/ruby
# encoding: utf-8
require_relative 'db.rb'

class MapUI

	def initialize(db)
		@names = Hash.new
		$warrings = Hash.new
		$nouplink = Array.new
		
		@arp,@hosts,@names = db.getHostsAndMacs(100)
		$arp = @arp
		$hosts = @hosts
		$names = @names
		@selftest = @hosts.keys
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

	def pushInfo(mac,msg)
		$warrings[mac] = Array.new if !$warrings.has_key?(mac)
		$warrings[mac].push(msg)
	end
end
