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
tsc = TaskControl.new('map','GetPortSpeed',hosts.size,'Getting speed of ports')
tsc.setGroupState(1)

p = ThreadPusher.new()

p.setThreadDataWorker() do |t|
	if t['list'] != nil
		db.transaction(t['host']) do
			if t['list'].has_key?("ports")
				p t['list']['ports']
				t['list']['ports'].each do |port,opts|
					p opts
					if opts['rate_rx'] != nil && opts['rate_tx'] != nil
						db.setPortRate(t['id'],port,opts['rate_rx'],opts['rate_tx'])	
					end
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
	pinfo "Getspeed #{host}"
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
	store = Hash.new
	ports = db.getPorts(row['id'])
	ports.each do |x|
		if x['mode'] == 'trunk'
			p x['port']
			port = x['port']
			data = wrk.getPortError(x['port'])
			next if data == nil 
			store[port] = Hash.new
			store[port]['tx'] = data['tx_bytes'] 
			store[port]['rx'] = data['rx_bytes'] 
			p store

			data = wrk.getPortError(x['port'])
			p "TX new #{data['tx_bytes'].to_i} prev #{store[port]['tx'].to_i}"
			p "RX new #{data['rx_bytes'].to_i} prev #{store[port]['rx'].to_i}"
			
			store[port]['tx'] = data['tx_bytes'].to_i - store[port]['tx'].to_i 
			store[port]['rx'] = data['rx_bytes'].to_i - store[port]['rx'].to_i
			# sql
			wrk.list['ports'][port]['rate_tx'] = store[port]['tx']   
			wrk.list['ports'][port]['rate_rx'] = store[port]['rx']   
		end
	end

	#Thread.current["list"] = Hash.new 
	#Thread.current["list"]['ports'] = ports 
	#p Thread.current["list"]

	p "--------------"
	Thread.current["list"] = wrk.list
	p wrk.list
	wrk.exit()
	pinfo "Exited"
	sm = nil
	GC.start
	tsc.incrementItem()
end

tsc.setTaskDesc("Successfully")
tsc.setGroupState(0)
