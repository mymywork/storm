#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'json'
require_relative 'amqp.rb'

class TaskControl
	
	def initialize(group,name,max,desc)
		@group = group
		@max = max
		@name = name
		@desc = desc
		@count = 0
		@percent = 0
		@amqp = MyAmqp.new('amqp://guest:guest@localhost')
		@amqp.declareExchange('taskcontrol')
		@semaphore = Mutex.new
		#@amqp.subscribe() do |delivery_info, properties, body|
		#	pdbg body
		#end
	end

	#
	# group 
	#

	def setGroupState(state)
		@amqp.publish(JSON.generate({ "action" => "set_group_state", "group" => @group, "state" => state }))
	end
	def clearGroup
		@amqp.publish(JSON.generate({ "action" => "clear_group", "group" => @group }))
	end

	#
	# task
	#

	def incrementItem()
		@semaphore.synchronize do
			@count=@count+1 if @count < @max
			@count=@max if @percent > 100
			@percent = (@count.to_f/@max.to_f*100).round
			pdbg " count = #{@count} max = #{@max}"
			pdbg " PERCENT #{@percent}"
			@amqp.publish(JSON.generate({ "action" => "update_task", "group" => @group, "progress" => @percent, "name" => @name, "desc" => @desc }))
		end
		@percent
	end

	def setPercent(v)
		@semaphore.synchronize do
			p v
			if v.to_i > 100
				@count = @max
				@percent = 100
			end
			p v.to_i
			@percent = v.to_i
			@amqp.publish(JSON.generate({ "action" => "update_task", "group" => @group, "progress" => @percent, "name" => @name, "desc" => @desc }))
		end
		@percent
	end

	def setTaskDesc(desc)
		@desc = desc
		@amqp.publish(JSON.generate({ "action" => "update_task", "group" => @group, "progress" => @percent , "name" => @name, "desc" => @desc }))
	end

end

