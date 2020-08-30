#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'json'
require_relative '../core/debug.rb'
require_relative '../core/amqp.rb'

class ExectionService

	def initialize

		@tasks = Hash.new
		@state = { 
			   "map" => { "desc" => "Build map", "state" => 0 , "exec" => "tmux new-window 'cd #{$rootpath};./zmake_all.sh new;zsh -i'"}, 
			   #"map" => { "desc" => "Build map", "state" => 0 , "exec" => "ruby ./testcol.rb"}, 
	     		   "backup" => { "desc" => "Backup configs", "state" => 0 , "exec" => "ruby #{$rootpath}/bkpcfg.rb"} 
			 }
		pinfo "Started amqp exchange service."
		@z = MyAmqp.new('amqp://guest:guest@localhost')
		@z.declareExchange('taskcontrol')
	
		@z.subscribe(name:'taskcontrol',block:false) do |delivery_info, properties, body|
			json = JSON.parse(body)
			p json
			# group
			grp = json['group'] 
			if json['action'] == 'get_tasks'
				p @tasks
				@tasks.each do |g,x|
					x.each do |n,z|
						@z.publish(JSON.generate({"action"=>"info_task" , "group" => g , "name" => n, "progress" => z["progress"], "desc" => z["desc"] }),name:'taskcontrol')	
					end
				end
			# start group binary
			elsif json['action'] == 'start_group'
				# process must same set state
				#@state[json['group']]["state"] = 1
				Process.spawn(@state[grp]["exec"])
			elsif json['action'] == 'stop_group'
				@state[grp]['state'] = 0	
				broadcastAllState()
			elsif json['action'] == 'set_group_state'
				@state[grp]['state'] = json['state']	
				broadcastAllState()
			elsif json['action'] == 'get_groups_state'
				broadcastAllState()
			elsif json['action'] == 'clear_group'
				@tasks.delete(grp)
			elsif json['action'] == 'update_task'
				name = json['name']
				progress = json['progress']
				desc = json['desc']
				if !@tasks.has_key?(grp) 
					@tasks[grp] = Hash.new
				end
				@tasks[grp][name] = { "progress" => progress, "desc" => desc }
			end
		end
		pinfo "Subscribe on taskcontrol."
		@z.declareExchange('execsvc')
		@z.subscribe(name:'execsvc',routing_key:'manager') do |delivery_info, properties, body|
			json = JSON.parse(body)
			p json
			if json['action'] == 'searchPortByMac'
				if json['mac'] =~ /[a-fA-F0-9:.-]+/
					exec = "ruby #{$rootpath}/app/search2.rb #{json['mac']}"
					run(exec,json['queue_key'])
				end
			elsif json['action'] == 'diagPort'
				if json['hostport'] =~ /[a-fA-F0-9:.-]+/
					exec = "ruby #{$rootpath}/app/diagport.rb --hspt #{json['hostport']} #{(json['recovery'] == true ? "-r" : "" )}"
					run(exec,json['queue_key'])
				end
			else
				return
			end	
		end
	end

	def broadcastAllState()
		@state.each do |g,v|
			@z.publish(JSON.generate({"action" => "state_groups" , "group" => g , "state" => v['state'], "desc" => v["desc"] }),name:'taskcontrol')	
		end
	end


	def run(exec,queue_key)
		IO.popen(exec) do |io|
			loop do	
				begin
					q = IO.select([io])
					break if q[0].length == 0
					x = io.read_nonblock(30)
					pinfo "Send to queue=#{queue_key}"
					p "#{x}"
					@z.publish(x, name: 'execsvc', routing_key: queue_key)
				rescue => e
					pwarn e
					break
				end
			end
		end
	end
end

a = ExectionService.new


