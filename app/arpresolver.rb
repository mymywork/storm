#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'

if ARGV.length < 2
	pdbg "ex: ./arpresolver.rb host-router port"
	exit
end

# database
db = Db.new
db.setMacForHost('192.168.1.120','3c:8a:b0:10:13:41')
hosts = db.getHostsWithoutMacs()

# switch
s = SwitchManager.new(ARGV[0],ARGV[1].to_i)
# get container class for switch model
wrk = s.getContainer()
s = nil

wrk.enableMode()
arp = wrk.getArpTable()
p arp
hosts.each do |row|
	if arp.has_key?(row['host'])
		pwarn "Resolving #{row['host']} #{arp[row['host']]['mac']}"
		db.setMacForHost(row['host'],arp[row['host']]['mac'])
	end
end

uhosts = db.getUnknowHosts()
p uhosts
arp.each do |host,arow|
	uhosts.each do |row|
		if arow['mac'] == row['mac']
			pwarn "Resolving unknow mac #{row['mac']} #{host}"
			db.setHostForMac(host,row['mac'])
		end
	end
end

