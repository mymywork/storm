#!/usr/bin/ruby
require 'rubygems'
require 'eventmachine'
require 'json'
require 'faye/websocket'

class WebSocketCommunication

	attr_accessor :ws

	def initialize
		@ready = false
		@ws = nil
		@sendarray = []
		trap "SIGINT" do
			puts "Exiting"
			close()
			sleep(3)
			exit 0
		end
		@t = Thread.new { evma() }
		#evma()
		@list = {}
		loop do
			p "wait websocket open in same work thread"
			sleep(1)
			break if @ready
		end
	end

	def publish(name,data)
		send({ 'action' => 'event', 'name' => name, 'data' => data })
	end

	def send(data)
		#p "Send to socket #{data}"
		#@ws.send(data)
		#@sendarray.push(data.to_json)
		@channel.push({ 'cmd' => 'send', 'data' => data})
	end
	def close()
		#p "close"
		#@ws.send(data)
		#@sendarray.push(data.to_json)
		@channel.push({ 'cmd' => 'close'})
	end

	def subscribe(name,&block)
		@list[name] = block
		send({ 'action' => 'subscribe', 'name' => name })
	end

	def evma
		begin
			EM.run {
				@channel = EventMachine::Channel.new
				@channel.subscribe do |msg| 
					if msg['cmd'] == 'send'
						@ws.send msg['data'].to_json 
					elsif msg['cmd'] == 'close'
						@ws.close()
					end
				end
				url = 'ws://127.0.0.1:8080/websocket'
				@ws = Faye::WebSocket::Client.new(url,nil,{ :headers => {'Authorization' => 'Basic XXXXXXXXXXXXXXXXX' } })
				@ws.on :open do |event|
					p "open websocket"
					#h = { 'action' => 'searchPortByMac', 'mac' => '11:22:33:44:55:66'}
					#@ws.send(h.to_json)
					@ready = true
				end

				@ws.on :message do |event|
					p [:message, event.data]
					json = JSON.parse(event.data)
					next if json['action'] != 'event'
					if @list.has_key?(json['name'])
						@list[json['name']].call(json['data'])	
					end
				end

				@ws.on :close do |event|
					p "close websocket code:#{event.code}, reason:#{event.reason}"
					ws = nil
				end
			}
		rescue => x
			p x
		end
	end
end

