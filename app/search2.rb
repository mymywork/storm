#!/usr/bin/ruby
require 'rubygems'
require_relative '../core/debug.rb'
require_relative '../core/utils.rb'

$dbglevel = 0
x = Utils.new
x.searchSwitchPortByMac(ARGV[0])
