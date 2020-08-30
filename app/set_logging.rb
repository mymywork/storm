#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'
require 'thread'
require 'thwait'

options = { :maxthreads => 10 }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-m", "--max-threads MAX", "Max threads") do |v|
		options[:maxthreads] = v.to_i
	end

	opts.on("-h", "--host HOST", "Single host") do |v|
		options[:host] = v
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
else
	hosts = db.getHostsWithServices()
end

p = ThreadPusher.new()

p.setThreadDataWorker() do |t|
end

p.pushThreads(options[:maxthreads],hosts) do |row|

	host = row['host']
	ports = row['services'].split(",").sort { |x,y| y.to_i <=> x.to_i } 
	port = ports[0].to_i
	# banner
	pinfo "Start thread host=#{host} port=#{port}"
	p row
	Thread.current["id"] = row['id']
	Thread.current["host"] = host
	pinfo "Set severity #{host}"
	sm = SwitchManager.new(host,port)
	wrk = sm.getContainer()
	if wrk == nil
		Thread.current["list"] = nil
		Thread.exit()
	end
	if wrk.version != '2900'
		wrk.exit()
		Thread.exit()
	end
	# get container class for switch model
	wrk.enableMode()
	wrk.ConfigurationMode do 
		wrk.setLogging("192.168.1.1")
	end
	wrk.writeCfg()
	wrk.exit()
	pinfo "Exited"
	sm = nil
	GC.start
end

