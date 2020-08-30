#!/usr/bin/ruby
require 'rubygems'
require 'date'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'

s = SwitchManager.new("192.168.0.1",23)
# get container class for switch model
wrk = s.getContainer()
s = nil
wrk.enableMode()

db = Db.new
hosts = db.getHosts()

hosts.each do |row|
	pinfo "Ping host #{row['host']}"
	wrk.ping(row['host'])
end
wrk.exit()
