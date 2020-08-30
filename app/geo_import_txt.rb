#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'


db = Db.new
db.transaction do 
	File.open(ARGV[0]).each do |line|
		ar = line.split("|")
		p ar
		host = ar[0].strip
		longitude = ar[1].strip
		latitude = ar[2].strip
		address = ar[3].strip
		db.setHostGeoData(host,address,latitude,longitude)	
	end
end
