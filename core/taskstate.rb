#!/usr/bin/ruby
require 'rubygems'
require_relative 'wsc.rb'

class TaskState < WebSocketCommunication

	attr_accessor :max

	def initialize(task,max=100,desc=nil)
		super()
		@semaphore = Mutex.new
		@task = task
		@desc = task
		@max = max
		@count = 0
		@percent = 0
		@state = {}
		if desc != nil
			@desc = desc
			@state['task'] = @task
			@state['desc'] = desc
			@state['percent'] = @percent
			@state['state'] = 'running'
			update()
		end
	end

	def reset
		@state = { "task" => @task }
	end

	def desc(desc)
		@desc = desc
		@state['task'] = @task
		@state['desc'] = desc
		update()
	end

	def running(max)
		@state = { "task" => @task, "state" => "running" ,"desc" => @desc, "precent" => @percent }
		update()
	end

	def stop()
		@state = { "task" => @task, "state" => "stop" }
		update()
		# for send message between thread
		close()
		sleep(1)
	end

	def increment()
		@semaphore.synchronize do
			@count=@count+1 if @count < @max
			@count=@max if @percent > 100
			@percent = (@count.to_f/@max.to_f*100).round
			pdbg " count = #{@count} max = #{@max} percent #{@percent}"
			@state['percent'] = @percent
		end
		update()
		@percent
	end
	
	def perc()

		@percent
	end

	def percent(v)
		@semaphore.synchronize do
			p v
			if v.to_i > 100
				@count = @max
				@percent = 100
			end
			p v.to_i
			@percent = v.to_i
			@state['percent'] = @percent
		end
		update()
		@percent
	end
	
	def update(state=nil)
		state = @state if state == nil
		publish('taskinfo',state)
		reset()
	end

end
