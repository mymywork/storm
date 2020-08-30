#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/debug.rb'
require_relative '../core/taskstate.rb'

# options default

state = {}

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-p", "--percent NUM", "Ready percentage of progress") do |v|
		state['percent'] = v.to_i
	end
	opts.on("-d", "--desc DESC", "Description of task") do |v|
		state['desc'] = v
	end
	opts.on("-t", "--task TASK", "Task name for change") do |v|
		state['task'] = v
	end
	opts.on("-r", "--running", "Run state") do |v|
		state['state'] = "running"
	end
	opts.on("-s", "--stop", "Stop state") do |v|
		state['state'] = "stop"
	end
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!

if state['task'] == nil 
	p "Task name not setted."
	exit
end	

p state
tsc = TaskState.new(state['task'],100)
tsc.update(state)
tsc.close()
sleep 1
