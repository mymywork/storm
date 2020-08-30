#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require 'pg'

begin
	
	def getHostZabbix(zhosts,host)
		zhosts.each do |x|
			next if x['host'] != host
			return x
		end
		return nil
	end

	db = Db.new
	shosts = db.geoList()
	#p shosts

 	con = PG.connect :dbname => 'zabbix', :user => 'postgres', :password => ''
	zhosts = con.exec "select a.* from hosts as a inner join hosts_groups as b on a.hostid = b.hostid and b.groupid=13"	
	
	con.exec "delete from hosts_links"	

	shosts.each do |r|
		next if r['plist'].length() == 0
		hsta = r['host']	
		za = getHostZabbix(zhosts,hsta)
		pinfo "Host #{za['host']} has zabbix id #{za['hostid']}"
		# show errors
		if za == nil
			pdbg "Host #{hsta} not found in zabbix."
			r['plist'].each do |x|
				pdbg "-> Not connected #{x['host']}"
			end
			next
		end
		r['plist'].each do |x|
			zb = getHostZabbix(zhosts,x["host"])
			if zb == nil
				pdbg "Host #{x["host"]} not found in zabbix."
			else
				pwarn "Downlink host #{zb['host']} has #{zb['hostid']}"
				con.exec "INSERT INTO hosts_links (host1,host2) VALUES (#{za['hostid']},#{zb['hostid']})"
			end
		end
	end

rescue PG::Error => e
	pdbg e.message 
ensure
	con.close if con
end
