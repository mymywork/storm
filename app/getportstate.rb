#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'
require_relative '../core/taskcontrol.rb'


# SQL DEBUG REQUEST
# select (select count(*) from ports where id=hostid and speed is null) as z,host from hosts where z > 10;
#

# options default

$dbglevel = 20
db = Db.new
options = { :maxthreads => 10 , :updatehosts => false }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-m", "--max-threads MAX", "Max threads") do |v|
		options[:maxthreads] = v.to_i
	end

	opts.on("-h", "--host HOST", "Single host") do |v|
		options[:host] = v
	end
	opts.on("-c", "--clean-info", "Clean tables (vlan)") do |v|
		db.deleteAllVlan()
		pdbg "Tables has been cleaned"
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

if options[:host] != nil
	hosts = [db.getHost(options[:host])]	
elsif options[:updatehosts]
	hosts = db.getUpdateHosts()
else
	hosts = db.getHostsWithServices()
end
#tsc = TaskControl.new('map','GetPortState',hosts.size,'Gathering information about port state.')
#tsc.setGroupState(1)

p = ThreadPusher.new()

p.setThreadDataWorker() do |t|
	if t['list'] != nil
		db.transaction(t['host']) do
			if t['list'].has_key?("ports")
				t['list']['ports'].each do |port,opts|
					db.setPortState(t['id'],port,opts['status'],opts['speed'])	
				end
			end
		end
	end
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
	pinfo "Getinfo #{host}"
	sm = SwitchManager.new(host,port)
	wrk = sm.getContainer()
	if wrk == nil
		tsc.incrementItem()
		Thread.current["list"] = nil
		Thread.exit()
	end
	# get container class for switch model
	wrk.enableMode()
	#wrk.getConfiguration()
	wrk.getPortsStatus()
	Thread.current["list"] = wrk.list
	wrk.exit()
	p wrk.list
	pinfo "Exited"
	sm = nil
	GC.start
	#tsc.incrementItem()
end

#tsc.setTaskDesc("Successfully")
#tsc.setGroupState(0)
