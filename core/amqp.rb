#!/usr/bin/ruby
require 'rubygems'
require "bunny"

class MyAmqp

	def initialize(url,name=nil)
		@conn = Bunny.new(url)
		@conn.start
		@exchanges = Hash.new
		@channel = @conn.create_channel
		declareExchange(name) if name != nil
	end

	def declareExchange(name)
		@default = name
		if !@exchanges.has_key?(name)
			#@exchanges[name] = @channel.fanout(name)
			#@exchanges[name].delete()
			@exchanges[name] = @channel.direct(name)
		end
		@exchanges[name]
	end

	def subscribe(name: nil,block: true,routing_key: nil)
		name = @default if name == nil
		q = @channel.queue("", :persistent => true, :auto_delete => true)
		q.bind(@exchanges[name], :routing_key => routing_key)
		begin
			q.subscribe(:block => block) do |delivery_info, properties, body|
				yield delivery_info, properties, body
			end
		rescue Interrupt => _
			@ch.close
			@conn.close
		end
		q
	end

	def publish(msg, name:nil, routing_key: nil )
		name = @default if name == nil
		#p "PUBLISH name=#{name} routing=#{routing_key}"
		@exchanges[name].publish(msg, :routing_key => routing_key)	
	end
end
