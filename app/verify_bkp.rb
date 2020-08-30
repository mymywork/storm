#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'pg'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'

begin
	bkpdir = "/var/tftproot/bkpcfg_20160328/"
	db = Db.new
	hosts = db.getHosts()
 	con = PG.connect :dbname => 'zabbix', :user => 'postgres', :password => ''
	res = con.exec "select a.host from hosts as a inner join hosts_groups as b on a.hostid = b.hostid and b.groupid=13"	
	pinfo "---------------------"
	pinfo "Not present in storm"
	pinfo "---------------------"
	res.each do |row|
		found = false
		hosts.each do |r|
			if r['host'] == row['host']
				found = true	
			end
		end
		if !found
			pdbg "#{row['host']}"
		end
	end
	pinfo "---------------------"
	pinfo "Not present in zabbix"
	pinfo "---------------------"
	hosts.each do |r|
		found = false
		res.each do |row|
			if r['host'] == row['host']
				found = true	
			end
		end
		if !found
			pdbg "#{r['host']}"
		end
	end
	pinfo "---------------------"
	pinfo "Not backuped hosts"
	pinfo "---------------------"
	hosts.each do |r|
		found = File.exist?("#{bkpdir}#{r['host']}.cfg")
		found = File.exist?("#{bkpdir}#{r['host']}.cfg.gz") if !found
		if !found
			pdbg "#{r['host']}"
		end
	end
rescue PG::Error => e
	pdbg e.message 
ensure
	con.close if con
end
