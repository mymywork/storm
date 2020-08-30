#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'

GC.start
GC.enable

switch = ARGV[0]
port = ARGV[1].to_i
result = switch

pinfo " * Search mac on #{switch}:#{port}"
sm = SwitchManager.new(switch,port)
wrk = sm.getContainer()
# get container class for switch model
wrk.enableMode()
plist = wrk.getPortsStatus()
p plist
rlist = []
#swport = wrk.getConfiguration()
plist.each do |k,v|
	if k =~ /epon[0-9]+\/[0-9]+:[0-9]+/
		port = k.delete("epon")
		headsignal = wrk.getPONHeadSignal(port)
		termsignal = wrk.getPONTerminalSignal(port)
		rlist.push("epon #{port} head #{headsignal} terminal #{termsignal}")
	end
end

rlist.each do |v|
	p v
end

