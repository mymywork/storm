require_relative './taskservice.rb'

class WsApi < TaskService

	def initialize
		super
		@actions = ['diagport','searchport','event','subscribe']
	end

	def call(sock,msg)
		#return nil if !@actions.include?(msg['action'])          
		if respond_to?(msg['action'])                            
			begin                                         
				#checkdead()
				p msg
				r = method(msg['action']).call(sock,msg)      
			rescue Exception => e                         
				p "EXCEPTION: #{e.inspect}"  
				p "MESSAGE: #{e.message}"
				e.backtrace.each do |x|
					p x                           
				end                                   
			end                                           
		else                                                  
			p "Method #{msg['action']} not found in protocol"
			sock.puts("Method #{msg['action']} not found in protocol\n")
			sock.close
			r = nil                                       
		end                                                   
	end



	def diagport(sock,json)
		p "BEFORE regex diagport"
		if json['hostport'] =~ /^([a-fA-F0-9:. -\/])+$/
			p "check regex diagport ok"
			exec = "ruby #{$rootpath}/app/diagport.rb --hspt #{json['hostport']} #{(json['recovery'] == true ? "-r" : "" )}"
			run(exec,sock)
			sock.close
		else
			p "check regex diagport fail"
			return
		end
	end
	
	def searchport(sock,json)
		if json['mac'] =~ /^([a-fA-F0-9:. -]+)$/
			exec = "ruby #{$rootpath}/app/search2.rb #{json['mac']}"
			run(exec,sock)
			sock.close
		else
			return
		end
	end
	
	def run(exec,sock)
		IO.popen(exec) do |io|
			loop do	
				begin
					q = IO.select([io])
					break if q[0].length == 0
					x = io.read_nonblock(100)
					pinfo "send to websocket: #{x}"
					p "#{x}"
					sock.puts(x)
				rescue => e
					pwarn e
					break
				end
			end
		end
	end
	

end

