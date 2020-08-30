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
require 'socket'
#require 'unixsocket'


#
# start
#

db = Db.new
x = db.geoList()
#p x
x.each do |z|
	z['plist'].each do |n|
		p "#{z['host']}|#{n['host']}"
	end
end
