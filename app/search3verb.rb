#!/usr/bin/ruby
require 'rubygems'
require_relative '../core/debug.rb'
require_relative '../core/utils.rb'

$dbglevel = 20
x = Utils.new
p x.searchSwitchPortByMac(ARGV[0])
