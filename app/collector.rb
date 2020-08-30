#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'
require_relative '../core/taskstate.rb'

$dbglevel = 20
db = Db.new
# options default

options = { :maxthreads => 10 , :updatehosts => false, :vlan => 100 }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-m", "--max-threads MAX", "Max threads") do |v|
		options[:maxthreads] = v.to_i
	end
	opts.on("-v", "--vlan VLAN", "Vlan number") do |v|
		options[:vlan] = v.to_i
	end
	opts.on("-c", "--clean", "Clean tables before start (ports,macs).") do |v|
		db.deleteAllPorts()
		db.deleteAllMac()
		pdbg "Tables has been cleaned"
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
# vlan
vlan = options[:vlan]
pwarn "Working for vlan=#{vlan}"
vlanint = vlan.to_i 

if options[:host] != nil
	hosts = [db.getHost(options[:host])]	
elsif options[:updatehosts]
	hosts = db.getUpdateHosts()
else
	# create mac table for vlan 
	hosts = db.getHostsWithServices()
end
p hosts
p = ThreadPusher.new()
tsc = TaskState.new('map',hosts.size,'Collecting macs in managment vlan.')

p.setThreadDataWorker() do |t|
	pinfo "---> WRITTING SQL DATA"
	if t['macs'] != nil
		db.transaction(t['host']) do
			t['macs'][vlanint].each do |o|
				#p "Line vlan=#{o['vlan']} id=#{t['id']} mac=#{o['mac']} port=#{o['port']}"
				db.insertMac(o['vlan'],t['id'],o['mac'],o['port'])
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
	Thread.current["host"] = row['host']
	sm = SwitchManager.new(host,port)
	wrk = sm.getContainer()
	if wrk == nil
		tsc.increment()
		Thread.current["macs"] = nil
		Thread.exit()
	end
	# get container class for switch model
	wrk.enableMode()
	t = wrk.getMacAddressByVlan(vlan)
	p t
	Thread.current["macs"] = t
	wrk.exit()
	pinfo "Exited"
	sm = nil
	GC.start
	pdbg tsc
	tsc.increment()
end

tsc.desc("Collecting - successfully")
sleep(1)
