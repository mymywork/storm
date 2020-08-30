#!/usr/bin/ruby
require 'rubygems'
require 'pty'
require 'readline'
require 'open3'
require 'socket'
require_relative 'debug.rb'


class Miniexpect

	attr_accessor :debug
	attr_accessor :raw
	attr_accessor :host
	attr_accessor :port

	attr_accessor :buffer
	attr_accessor :tmpbuf
	attr_accessor :templates_list

	attr_accessor :list
	attr_accessor :level
	attr_accessor :pid

	attr_accessor :timeout
	attr_accessor :switch
	attr_accessor :block

	WRAP = 0
	TCP = 1
	attr_accessor :mode

	attr_accessor :ss_buffer

	def initialize(host,port,setsize=false,&block)

		@block = block
		@host = host
		@port = ( port == 0  ? 23 : port )
		@timeout = false
		@timeout_sec = 10
		@ss_buffer = nil
		self.connect(setsize) 
	end

	def connect(setsize)
		
		wrap = "./ttywrap.sh"
		cmd = ( @port == 22 ) ? "ssh" : "telnet"
		portstr = ( @port == 22 ) ? "-p #{@port}" : @port.to_s
		host = @host

		if setsize
			@mode = TCP
			#r = PTY.spawn(wrap,cmd,host,portstr) 
			#@input, @output, stderr, wait_thr = Open3.popen3("#{wrap} #{cmd} #{host} #{port}")
			sock = TCPSocket.new(host, port)
			@input = sock
			@output = sock
		else
			if cmd == 'ssh'
				@mode = WRAP
				r = PTY.spawn(cmd,host,portstr) 
				@pid = nil #wait_thr[:pid]
				@input=r[1]
				@output=r[0]
				@pid = r[2]
				@output.sync = true
				@input.sync = true
			else
				@mode = TCP
				#@input, @output, stderr, wait_thr = Open3.popen3("#{cmd} #{host} #{port}")
				@socket = TCPSocket.new(host, port)
				@input = @socket
				@output = @socket
			end
		end
		@last=""
		@buffer = ""
		
		pinfo "MINNIEXPECT pid=#{@pid} host=#{host} port=#{port} cmd=#{cmd}\n"

		@tmpidx = 0
		@level = -1
		@list = []
		@templates_list = {}
		@protocols_string = {}
		@protocols_binary = {}
	
		@block.call(@pid,host) if @block != nil
	end

	def reconnect(setsize)
		pwarn "Reconnect to #{@host}:#{@port}"
		close()
		checkClose?()
		#Process.wait
		self.connect(setsize)
	end

	def screenshot_buffer_start
		@ss_buffer = ""
	end

	def screenshot_buffer_stop
		tmp = @ss_buffer
		@ss_buffer = nil
		tmp
	end

	def each(*args,&block)
		begin
			each_internal(*args,&block)		
		rescue => e
			fexcept(e,@host)
		end
	end

	def each_internal(*args,&block)
		pdbg "(mexpect) -> Entering to each"
		slf = self
		# enter on new level
		@level = @level + 1
		@list[@level]=[]
		@timeout_sec = 10
		# add templates
		args.each do |x|
			slf.list[slf.level].concat(slf.templates_list[x])
		end
		# increment level for internal each cycles
		brk=false
		match=false
		hst = @host.gsub("192.168.","")
		instance_eval(&block) if block != nil
		while true
			#p "tmpidx:#{@tmpidx}"
			if @tmpidx == 0
				#p "Before:#{@buffer.unpack('C*').map {|e| e.to_s 16} }"
				break if recv(@output) == nil 
				@buffer=@last.concat(@buffer)
				#p "After:#{@buffer}"
				@last=""
				@tmpidx=0
				
				@protocols_binary.each do |a|
					@buffer = a[1].call(self,@buffer)
				end

				# convert wrong binary into utf-8 string
  				if !@buffer.valid_encoding?
					#@buffer = @buffer.force_encoding('UTF-8')
					@buffer.encode!("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '')
				end

				@protocols_string.each do |a|
					@buffer = a[1].call(self,@buffer)
				end
				
				# screenshot
				@ss_buffer.concat(@buffer) if @ss_buffer != nil

				#praw "[raw-noncrlf #{hst}]: #{@buffer}"
				@tmpbuf = @buffer.split(/\n\r|\r\n|\n/)
				#p @tmpbuf
				# add "\n" to each line
				@tmpbuf.collect!.with_index do |x,i| 
					# check if nil
					x = ( x == nil ) ? "" : x;
					a = x.split("\r")
					c = x.count("\r")
					#p c
					# print
					#p a
					#a.each do |v|
						#p "sub: #{v}"
					#end
					# do 
					if a.length == 0
						z = ""
					else
						z = a.last
					end	
					# if last line not have cr or lf return as is as
					next z if slf.tmpbuf.size == i+1 && ( slf.buffer[-1] != "\n" && slf.buffer[-2] != "\n" ) 	
					z.concat("\n")
				end
				#pwarn @tmpbuf
			end
			
			while @tmpidx < @tmpbuf.count
			#@tmpbuf.each do |curline| 
				curline = @tmpbuf[@tmpidx]
				if curline[-1] != "\n" && curline[-2] != "\n" && has_data(@output) && @tmpidx == @tmpbuf.count-1
					#p "Has data on last line"
					@last = curline
					@tmpidx = 0
					break
				end
				@line = curline
				@tmpidx = @tmpidx + 1
				# debug
				praw "[raw #{hst}]: #{@line}"
				# each expects
				@list[@level].each do |exp|
					begin
						match = @line.match(exp[0]) do |c|
							pinfo "FOUND: #{c}"
							exp[1].call(c,exp[2])
							true
						end
						break if match
					rescue => exp
						if exp.message != "break from proc-closure"
							#p exp.backtrace
							p exp.inspect
							exp.backtrace.each {|x| p x}
						end
						#p exp.inspect
						# break in block
						brk = true
						match = true
						pinfo "break 1"
						break
					end
				end
				# if line not matched and not end crlf - try recving last part
				if @line.match(/(\r|\n)$/) == nil && match != true 
					#p "Adding last"
					@last = @line
					#p "[last]:#{@last}"
				end	
				# if intercallback each interated all lines and break(nonrecv) 
				break if @tmpidx == 0
				if brk == true
					#pinfo "break 2 (by user)"
					break
				end
				#pwarn "next line"
			end #while @tmpidx < @tmpbuf.count
			@tmpidx = 0 if @tmpidx >= @tmpbuf.count
			#pinfo "break 3"
			break if brk == true
		end
		# leave level
		@list.delete(@level)
		@level = @level - 1
		# dbg
		pdbg "(mexpect) -> Leave each"
	end

	def templates(*args,&block)
		# enter level
		pinfo "Templates"
		@level = @level + 1
		@list[@level]=[]
		instance_eval(&block)
		key = args[0]
		# template['some'] = [ [pattern,block,pattern] , [pattern,block,pattern]  ]
		@templates_list[key]=@list[@level]
		# leave level
		@list.delete(@level)
		@level = @level - 1
		pinfo "End templates"
	end

	def protocol_clear()
		@protocols_string={}
		@protocols_binary={}
	end

	def protocol_string(*args,&block)
		# enter level
		key = args[0]
		pinfo "Protocols string #{key}."
		@protocols_string[key]=block
	end
	
	def protocol_binary(*args,&block)
		# enter level
		key = args[0]
		pinfo "Protocols binary #{key}."
		@protocols_binary[key]=block
	end

	def procedure(*args,&block)
		@block=block
	end

	def setTimeout(x)
		@timeout_sec = x		
	end

	def expect(*pattern,&block)
		pdbg "(mexpect) called expect set regex #{pattern[0].to_s} param='#{pattern[1]}'"
		@list[@level].push([pattern[0],block,pattern[1]])
		#p pattern[0]
	end

	def has_data(output)
		begin
			ready = IO.select([output],[],[output],1)
			if ready == nil
				return false 
			end
			return true
		rescue => exp
			pdbg "Stream output closed: #{exp.message}"
			checkClose?()
			#pwarn exp.message
			return nil
		end
		return @buffer
	end

	def recv(output)
		begin
			ready = IO.select([output],[],[output],@timeout_sec)
			if ready == nil
				@timeout = true
				return nil 
			end
			readable = ready[0]
			errorable = ready[2]
			if errorable.count != 0
				pdbg "ERR: #{errorable}"
				return nil
			end
			@buffer=""
			output.readpartial(1024, @buffer)
		rescue => exp
			pdbg "Stream output closed: #{exp.message}"
			checkClose?()
			@timeout = true
			#pwarn exp.message
			return nil
		end
		return @buffer
	end

	def send(data)
		begin
			pdbg "(mexpect) Send data:#{data}"
			@input.write(data)
		rescue => exp
			pdbg "Stream input closed: #{exp.message}"
			checkClose?()
		end
	end

	def close()
		begin
			if @mode == TCP
				@socket.close
			else
				pinfo "Kill process #{@pid}"
				Process.kill("KILL", @pid)
			end
		rescue => e
			pdbg e.message	
		end
	end

	#
	# if closed = true
	#
	def checkClose?(flag=0)
		Debug.closeAll()
		if @mode == TCP
			return @socket.closed?	
		else
			return waitExitStatus(flag)	
		end
	end

	def waitExitStatus(flag=0)
		begin
			pdbg "Wait pid #{@pid}"
			pid = Process.waitpid(@pid, flag)
			pwarn "Waited PID ready = #{pid}",0
			return false if pid == nil	# if no exited pid
			return true			# if has exited pid
		rescue => exp
			pdbg "#{exp.message}"
			return true
		end
	end

	def flush()
		@output.flush
		@input.flush
	end
end
