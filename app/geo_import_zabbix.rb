#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require 'pg'

begin
	db = Db.new
 	con = PG.connect :dbname => 'zabbix', :user => 'postgres', :password => ''
	res = con.exec "select a.host as host,b.location as address,b.location_lat as latitude,b.location_lon as longitude from hosts as a inner join host_inventory as b on a.hostid = b.hostid where b.location_lat != ''"	
	db.transaction do
		res.each do |row|
			host = db.getHost(row['host'])
			if host != nil
				pinfo "Host added #{row['host']} #{row['latitude']} #{row['longitude']} address=#{row['address']}"
				db.setHostGeoData(row['host'],row['address'].delete("'"),row['latitude'],row['longitude'])
			else
				pdbg "Host #{row['host']} is not present in storm."
			end
		end
	end
rescue PG::Error => e
	pdbg e.message 
ensure
	con.close if con
end
