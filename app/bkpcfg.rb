#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require 'fileutils'
require_relative '../core/config.rb'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'
#require_relative '../core/taskcontrol.rb'
require_relative '../core/taskstate.rb'


options = { :maxthreads => 10 , :host => nil , :bkpdir => nil , :bkpsrv => '192.168.3.5' }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-m", "--max-threads MAX", "Max threads") do |v|
		options[:maxthreads] = v.to_i
	end
	
	opts.on("-d", "--directory DIR", "Directory for backup") do |v|
		options[:bkpdir] = v
	end
	
	opts.on("-s", "--server HOST", "Backup server") do |v|
		options[:bkpsrv] = v
	end
	
	opts.on("-h", "--host HOST", "Single host") do |v|
		options[:host] = v
	end

	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!

if options[:bkpdir] == nil
	d = DateTime.now
	bkpdir = d.strftime("bkpcfg_%Y%m%d")
	options[:bkpdir] = bkpdir
	begin
		Dir.mkdir("/var/tftproot/#{bkpdir}",0755)
	rescue => e
		p e
	end
	begin
		Dir.mkdir("#{$rootpath}/log/#{bkpdir}",0755)
	rescue => e
		p e
	end
	FileUtils.chown "nobody", "root", "/var/tftproot/#{bkpdir}"
	FileUtils.chown "nobody", "root", "#{$rootpath}/log/#{bkpdir}"
end

db = Db.new
hosts = nil
if options[:host] != nil
	hosts = [db.getHost(options[:host])]	
else
	hosts = db.getHostsWithServices()
end


p hosts
tsc = TaskState.new('backup',hosts.size,'Backup configuration')

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
	pinfo "Backup config #{host}"
	sm = SwitchManager.new(host,port) do |mypid,myhost|
		begin
			Debug.openFile("#{$rootpath}/log/#{options[:bkpdir]}/#{myhost}.log")
			Debug.setRedirectToLogging("#{$rootpath}/log/#{options[:bkpdir]}/#{myhost}.log")
		rescue => x
			p x
		end

	end
	wrk = sm.getContainer()
	if wrk == nil
		tsc.increment()
		Thread.current["list"] = nil
		Thread.exit()
	end
	# get container class for switch model
	wrk.enableMode()
	if wrk.vendor == 'juniper'
		wrk.copyCfgToSSH(options[:bkpsrv],"/var/tftproot/#{options[:bkpdir]}/#{host}.cfg")
	else
		wrk.copyCfgToTftp(options[:bkpsrv],"/#{options[:bkpdir]}/#{host}.cfg")
	end
	Thread.current["list"] = wrk.list
	wrk.exit()
	pinfo "Exited"
	sm = nil
	GC.start
	tsc.increment()
end
tsc.desc("Successfully")
tsc.stop()
