#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'webrick'
require 'webrick/websocket'
require 'json'
require_relative '../core/config.rb'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/erbcontext.rb'
require_relative '../core/amqp.rb'

GC.start
GC.enable

x = MyAmqp.new('amqp://guest:guest@localhost','clientqueue')

server = WEBrick::HTTPServer.new :Port => 8081
server.mount "/", WEBrick::HTTPServlet::FileHandler, "#{$rootpath}/www"
server.mount_proc('/pushqueue'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()
	host = nil
	if params.has_key?('cid') && params.has_key?('mac')
		if params['cid'].match(/[0-9]{1,5}/) != nil && params['mac'].match(/[a-fA-F0-9:]{17}/) != nil
			case params['cid'].to_i
			when 20800
				pdbg "Discard #{params['cid']} and #{params['mac']}"
				resp.body = JSON.generate({ "status"=> 'discard' })
			else
				json = JSON.generate({ 'action' => 'searchPort', 'cid' => params['cid'], 'mac' => params['mac']})
				x.publish(json)
				resp.body = JSON.generate({ "status"=> 'pushed inqueue' })
			end
		else
			pdbg "Discard #{params['cid']} and #{params['mac']}"
			resp.body = JSON.generate({ "status"=> 'discard' })
		end
	end
}
trap('INT') { server.stop }
server.start
exit

