#!/usr/bin/ruby
require 'thread'
require 'thwait'

class ThreadPusher

	def initialize()
		@func_complete = nil
	end

	def setThreadDataWorker(&block)
		@func_complete = block
	end
	def pushThreads(maxthread,list)

		curthread = 0
		readythread = 0
		threads = []

		pinfo "Thread task count = #{list.count}"
		list.each do |param|
			if curthread < maxthread
				t = Thread.new(param) do |iparam|
					begin
						yield iparam
					rescue => e
						host = ( iparam['host'] != nil ? iparam['host'] : '' )
						fexcept(e,host)
					end
				end
				threads.push(t)
				curthread = curthread + 1
			end
			# if thread is not ready fulling queue
			if curthread < maxthread
				next
			end
			# wait thread
			ths = ThreadsWait.new(threads)
			t = ths.next_wait
			pwarn "Thread #{t} has terminated."
			# free resources for one thread
			curthread = curthread - 1
			threads.delete(t)
			readythread = readythread + 1
			pwarn "---> READY THREAD (#{readythread})"
			# write data
			pinfo "---> COMPLETING THREAD DATA"
			begin
				@func_complete.call t if @func_complete != nil
			rescue => exp
				p exp
				host = ( t['host'] != nil ? t['host'] : '' )
				fexcept(exp,host)
			end
		end
		if threads.count != 0
			ThreadsWait.all_waits(threads) do |t|
				pwarn "Last thread #{t} has terminated."
				# free resources for one thread
				curthread = curthread - 1
				threads.delete(t)
				readythread = readythread + 1
				pwarn "---> LAST READY THREAD (#{readythread})"
				# write data
				pinfo "---> LAST COMPLETING THREAD DATA"
				begin
					@func_complete.call t if @func_complete != nil
				rescue => exp
					p exp
					host = ( t['host'] != nil ? t['host'] : '' )
					fexcept(exp,host)
				end
			end
		end
	end
end
