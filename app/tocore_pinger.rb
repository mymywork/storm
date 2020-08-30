#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'

# options default

options = { :maxthreads => 10 , :updatehosts => false }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-m", "--max-threads MAX", "Max threads") do |v|
		options[:maxthreads] = v.to_i
	end

	opts.on("-h", "--host HOST", "Single host") do |v|
		options[:host] = v
	end

	opts.on("-u", "--updatehosts", "Work only with hosts from updatehosts table.") do |v|
		options[:updatehosts] = true
	end
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!

#
# start
#

db = Db.new
if options[:host] != nil
	hosts = [db.getHost(options[:host])]	
elsif options[:updatehosts]
	hosts = db.getUpdateHosts()
else
	hosts = db.getHostsWithServices()
end

p = ThreadPusher.new()

p.pushThreads(options[:maxthreads],hosts) do |row|

	host = row['host']
	ports = row['services'].split(",").sort { |x,y| y.to_i <=> x.to_i } 
	port = ports[0].to_i
	pinfo "Host pinger: #{host} #{port}"
	Thread.current["host"] = host
	sm = SwitchManager.new(host,port)
	wrk = sm.getContainer()
	next if wrk == nil
	# get container class for switch model
	wrk.enableMode()
	wrk.ping("192.168.1.1")
	wrk.exit()
	pinfo "Exited"
	sm = nil
	GC.start
end
