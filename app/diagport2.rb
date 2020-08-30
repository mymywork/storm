#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'

def recoveryPort(port)
	exit if $recovery == 0
	$wrk.ConfigurationMode do 
		pwarn "Shutdown port #{port}",0
		$wrk.setPortState(port,false)
		pwarn "Wait for #{$timeShutdown} sec",0
		sleep($timeShutdown)
		pwarn "No Shutdown #{port}",0
		$wrk.setPortState(port,true)
	end
	$recovery = $recovery - 1
end

#
# options default
#
options = { :host => nil , :idxport => 1, :recover => false }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-r", "--recover", "Enable port-shutdown recovery.") do |v|
		options[:recover] = true
	end

	opts.on("-h", "--hspt HOST:PORT_INDEX", "Check port of host.") do |v|
		x = nil
		x = v.match(/([0-9]+)[.-]{1}([0-9]+):([0-9\/:]+)/) if x == nil	
		exit if x == nil || x.length != 4 
		options[:host] = "192.168.#{x[1].to_i}.#{x[2].to_i}"	
		options[:port] = x[3]
	end

	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!


$timeShutdown = 60
$timeTransmit = 10

$dbglevel=100
host = options[:host]

ethport = options[:port]
idxport = ethport.to_i

pinfo "Connecting #{host} port #{ethport}",0
sm = SwitchManager.new(host,23)
wrk = sm.getContainer()
$wrk=wrk
# get container class for switch model
wrk.enableMode()
state = nil
mac = nil
crcerr = nil
rxpacket = nil
allowRecovery = options[:recover]
#list = wrk.getPortsStatus()
#exit

#
# check port
#
if !wrk.isPonPort(ethport)
	
	# get ports status
	#
	doRecovery = false
	$recovery = 1
	loop do
		pinfo "Getting ports status.",0
		list = wrk.getPortsStatus()
		# selecting port
		ethport = list.keys[idxport.to_i-1]
		pinfo "Checking port #{ethport}",0
		if list[ethport]['status'] == "UP"
			pinfo "Ports UP.",0
			state = true
			break
		else
			pdbg "Ports DOWN.",0
			state = false
			doRecovery = true
		end
		if doRecovery && allowRecovery 
			recoveryPort(ethport)
		else
			break
		end
	end
end 
#
# get mac address
#
loop do
	m = wrk.getMacAddressByPort(ethport)
	if m.length != 0
		pinfo "Mac addresses on port: #{m[ethport].map {|x| x['mac'] }.join(" , ")}",0	
		break
	else
		pdbg "No found mac on port",0
		mac = nil
		break
		#recoveryPort(ethport)
	end
end

#
# signale
#
if wrk.isPonPort(ethport)
	signale_ch = wrk.getPONFromClientToHeadSignal(ethport)
	signale_hc = wrk.getPONFromHeadToClientSignal(ethport)
	listports = wrk.getPONClientPortsError(ethport)
	signale_ch = "fail" if signale_ch == nil
	signale_hc = "fail" if signale_hc == nil
	pwarn "Signale from client to head = #{signale_ch}",0
	pdbg "Signale from head to client = #{signale_hc}",0
	listports.each do |port,features|
		pwarn "Client ONU/ONT Port (#{port})",0
		features.each do |k,v|
			pinfo "#{k} = #{v}",0
		end
	end
else
	#
	# get ddm 
	#
	ddm = wrk.getPortsDDM()
	if ddm != nil 
		
		temp = ddm['ports'][ethport]['temp']
		txmw = ddm['ports'][ethport]['tx_mw']
		rxmw = ddm['ports'][ethport]['rx_mw']
		txdbm = ddm['ports'][ethport]['tx_dbm']
		rxdbm = ddm['ports'][ethport]['rx_dbm']
		pinfo "DDM port=#{ethport} temperature=#{temp} Tx mW=#{txmw} / Tx dBm=#{txdbm} | Rx mW=#{rxmw} / Rx dBm =#{rxdbm}",0	
	else
		pinfo "DDM not supported.",0
	end

	#
	# get traffic and error #1 
	#
	err = wrk.getPortError(ethport)
	#pinfo err
	pinfo "Traffic rx_bytes=#{err['rx_bytes']} tx_bytes=#{err['tx_bytes']}",0
	rxbytes=err['rx_bytes']
	crcerr=err['rx_crc_error']
	if err['rx_crc_error'] != 0
		pdbg "Port has CRC errors #{err['rx_crc_error']}",0
	else
		pinfo "No CRC errors",0
	end
	#
	pwarn "Sleeping for #{$timeTransmit} sec, wait for traffic transmiting.",0
	sleep($timeTransmit)

	#
	# get traffic and error #2 
	#
	$recovery = 1
	loop do
		err = wrk.getPortError(ethport)
		doRecovery = false
		if err['rx_crc_error'] != crcerr
			pdbg "Port CRC errors growing for #{$timeTransmit} sec #{err['rx_crc_error']}",0
			doRecovery = true
		else
			pinfo "No CRC errors growing.",0
		end
		if err['rx_bytes'] == rxbytes
			pdbg "No RX traffic recvied for #{$timeTransmit} sec #{err['rx_bytes']}",0
			doRecovery = true
		else
			pinfo "RX traffic is reciving succefully #{err['rx_bytes']}.",0
			break
		end
		#
		# recover
		#
		if doRecovery && allowRecovery 
			recoveryPort(ethport)
			pwarn "Sleeping for #{$timeTransmit} sec, wait for traffic transmiting.",0
			sleep($timeTransmit)
		else
			break
		end
	end
end
#err.sort.each do |k,v|
#	pdbg "#{k}=#{v}",0
#end
#pwarn "Clear counters on port"
#wrk.clearPortCounter(i)
wrk.exit()
pinfo "Exited"
sm = nil

