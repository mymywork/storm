class Exchange
	
	def initialize
		@actions = ['diagport','searchport','event','subscribe']
		@exchanges = Hash.new
	end

	def event(sock,json)
		p 'event'
		if json.has_key?('name')
			n = json['name']
			p n
			if @exchanges.has_key?(n)
				j = json.to_json
				# send to all in exchange
				closed = []
		
				@exchanges[n].each do |s|
					next if s == sock
					begin
						p "send to #{s}"
						s.puts(j)
					rescue => e
						closed.push(s)	
					end
				end
				closed.each do |s|
					@exchanges[n].delete(s)
					p "event delete socket #{s}"
				end
			end
		end
	end

	def subscribe(sock,json)
		if json.has_key?('name')
			e = json['name']
			if @exchanges.has_key?(e)
				@exchanges[e].push(sock)		
			else
				@exchanges[e] = [sock]
			end
		end
	end
	
	def unsubscribe(sock,json)
		if json.has_key?('name')
			e = json['name']
			if @exchanges.has_key?(e)
				@exchanges[e].delete(sock)		
			end
		end
	end
	
	def checkdead()
		@exchanges.each do |k,v|
			closed = []
			v.each do |s|
				p s.methods
				begin
					send_frame(Frame.new(:ping, nil))
				rescue => e
					closed = []
				end
			end
			closed.each do |s|
				@exchanges[k].delete(s)
				p "checkdead delete socket #{s}"
			end
		end
	end

	def close(sock)
		@exchanges.each do |k,v|
			p "close sock #{sock}"
			p "sock is present #{@exchanges.include?(sock)}"
			v.delete(sock)
		end

	end

end
