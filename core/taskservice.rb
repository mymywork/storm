require_relative './exchange.rb'

class TaskService < Exchange
	
	def initialize
		super
		@taskevent = 'taskinfo'
		@states = {}
		@states['map'] = { 'task' => 'map', 'desc' => 'Generate map.', 'state' => 'stop', 'percent' => 0 }
		@states['backup'] = { 'task' => 'backup', 'desc' => 'Backup configs.', 'state' => 'stop', 'percent' => 0 }
		@states['progress'] = { 'task' => 'progress', 'desc' => 'Test exchange progress realtime ui.', 'state' => 'stop', 'percent' => 0 }
		p "states"
	end

	def event(sock,json)
		super
		control(sock,json)
		# save state
		if json.has_key?('name') && json['name'] == 'taskinfo'
			d = json['data']
			task = d['task']
			if @states.has_key?(task)
				# update
				d.each do |k,v|
					@states[task][k] = v
				end
			else
				# init
				@states[task] = d
			end
		end
	end

	def subscribe(sock,json)
		super
		# send all tasks on subscribe
		if json.has_key?('name') && json['name'] == 'taskinfo'
			@states.each do |k,v|
				sock.puts({ 'action' => 'event', 'name' => 'taskinfo', 'data' => v }.to_json)
			end
		end
	end

	def control(sock,json)
		if json.has_key?('name') && json['name'] == 'taskinfo'
			d = json['data']
			if d.has_key?('task') && d.has_key?('state')
				if d['task'] == 'map'
					if d['state'] == 'start'
						e = "tmux new-window 'cd #{$rootpath};./zmake_all.sh new;zsh -i'"		
						Process.spawn(e)
					else

					end
				end
				if d['task'] == 'backup'
					if d['state'] == 'start'
						e = "ruby #{$rootpath}/app/bkpcfg.rb"	
						Process.spawn(e)
					else

					end
				end
				if d['task'] == 'progress'
					if d['state'] == 'start'
						e = "ruby #{$rootpath}/apptest/progress.rb"	
						Process.spawn(e)
					else

					end
				end
			end
		end
	end

end
