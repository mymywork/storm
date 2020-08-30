#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require 'nokogiri'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'


$dbglevel = 20
db = Db.new
file = nil

options = { :maxthreads => 10 , :updatehosts => false, :vlan => 100 }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"
	opts.on("-f", "--file FILE", "File with hosts.") do |v|
		file = v	
	end
	opts.on("-c", "--clean", "Clean tables before start (hosts).") do |v|
		db.deleteAllHosts()
		pdbg "Tables has been cleaned"
	end
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!

def loadxml(file)
	 list = Hash.new
	 xml = File.open(file)
	 doc = Nokogiri::XML(xml)
	 doc.xpath('//nmaprun/host').each do |x|
		 host = x.at_xpath('./address/@addr',{ 'addrtype' => 'ipv4' }).content
		 timestamp = x.at_xpath('@starttime').content
		 list[host] = Hash.new
		 list[host]['timestamp'] = timestamp
		 list[host]['ports'] = []
		 x.xpath('./ports/port').each do |z|
			 port = z.xpath('@portid').first.content
			 state =  z.at_xpath('.//state/@state').content
			 if state == "open"
				 p "Host=#{host} port=#{port} state=#{state}"
				 list[host]['ports'].push(port)
			 end
		 end
	 end
	 list
end

hosts = loadxml(file)

db.transaction do 
	hosts.each do |host,param|
		services = param['ports'].join(',')
		pinfo "Adding host #{host} services #{services}"
		db.setHostServices(host,services)
	end
end
pwarn "Total hosts: #{hosts.length}"
