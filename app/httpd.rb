#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'webrick'
require 'json'
require 'webrick/websocket'
require 'net/ldap'
require 'net/http'
require "sablon"
require_relative '../core/config.rb'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/db_billing.rb'
require_relative '../core/erbcontext.rb'
require_relative '../core/amqp.rb'
require_relative '../core/db_mysql_billing.rb'
require_relative '../core/wsapi.rb'

GC.start
GC.enable

$dbglevel = 0

db = Db.new 
dbbl = DbBilling.new
dbm = MysqlBillingTransport.new  
$wsapi = WsApi.new

accounts = {
	'admin' => '1234'
}
baseurl = "/storm"
defright = [/^\/$/,/^\/websocket/,/^\/outages/,/^\/search/,/^\/map/,/^\/searchport/,/^\/files.*/,/^\/geo/,/^\/geolist/,/^\/dndtree/,/^\/visual/,/^\/gethostinfo/]
telright = [/^\/$/,/^\/websocket/,/^\/outages/,/^\/search/,/^\/map/,/^\/searchport/,/^\/files.*/,/^\/geo/,/^\/geolist/,/^\/dndtree/,/^\/visual/,/^\/gethostinfo/,/^\/telephony/,/^\/getvoiprequest/]
$access = { 
	"user2" => [/^\/$/,/^\/websocket/,/^\/map/,/^\/files.*/,/^\/d3tree/,/^\/gethostinfo/,/^\/geolist/,/^\/geo/],
	"user1" => telright, 
	"admin" => defright
}

def checkRights(url,user)
	if $access.has_key?(user)
		profile = $access[user]
	else
		profile = $access["default"]
	end
	hasrights = false
	profile.each do |v|
		if url =~ v
			return true
		end
	end
	return hasrights
end

handler = Proc.new do |req, resp|
	#next if req.path =~ /websocket/
	WEBrick::HTTPAuth.basic_auth(req, resp, '') do |user, password|
		next false if user == nil || password == nil
		next false if user == "" || password == ""

		r = false
		if accounts.has_key?(user)
			r = ( accounts[user] == password ) ? true : false
		else
			ldap = Net::LDAP.new
			ldap.host = "ldaphost"
			ldap.port = 389
			p "User #{user}"
			ldap.auth "#{user}@corp", password
			r = ldap.bind
			accounts[user] = password if r
		end
		if r
			# authentication success
			pdbg "Success auth #{user}"
			next true
		else
			# authentication failed
			pdbg "Fail auth #{user}"
			next false
		end
	end
	
	result = checkRights(req.path,req.user)
	if !result
		resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./deny.erb') 
		raise WEBrick::HTTPStatus[200]
	end
end

server = WEBrick::Websocket::HTTPServer.new :Port => 8080, 
	:RequestCallback => handler, 
	:Logger => WEBrick::Log.new("#{$rootpath}/log/webrick.log",WEBrick::Log::DEBUG), 
	:AccessLog => [[WEBrick::Log.new("#{$rootpath}/log/webrick_access.log",WEBrick::Log::DEBUG),WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
server.mount "/files/", WEBrick::HTTPServlet::FileHandler, "#{$rootpath}/www"
server.mount_proc('/') { |req, resp|
	#p req
	resp['Content-Type'] = 'text/html'
	resp.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, "#{baseurl}/outages")
#resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./map.erb') 
}
server.mount_proc('/outages') { |req, resp|
	#p req
	pw = accounts[req.user]
	resp['Content-Type'] = 'text/html'
	resp.body = (ERBContext.new({ "param" => { "login" => req.user, "password" => pw , "baseurl" => baseurl } })).renderWithLayout("#{$rootpath}/template/templ.erb",'./outages.erb') 
}
server.mount_proc('/map') { |req, resp|
	resp['Content-Type'] = 'text/html'
	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./map.erb') 
}
server.mount_proc('/gethostinfo') { |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()
	host = nil
	ports = nil
	status = "fail"
	if params.has_key?('host')
		host = db.getHost(params['host'])
		if host != nil 
			ports = db.getPorts(host['id'])
			# Рекурсивная сортировка портов.
			ports.sort! do |x,y|
				mx = x['port'].split(/[\/a-z]+/)
				my = y['port'].split(/[\/a-z]+/)
				#p "Compared #{mx} <=> #{my}"
				c = ( mx.length > my.length ? my.length : mx.length )
				r = 0
				n = 0
				while ( n < c ) do
					#p "Compared #{mx[n]} <=> #{my[n]}"
					if mx[n] =~ /\d+/ and my[n] =~ /\d+/
						zx = mx[n].to_i
						zy = my[n].to_i
					elsif mx[n] =~ /[A-Z]/ and my[n] =~ /[A-Z]/
						zx = mx[n]
						zy = my[n]
					end
					#p "Weigth #{zx} <=> #{zy}"
					r = zx <=> zy
					n = n + 1
					next if r == 0
					break
				end
				next r
			end
			status = "ok"
		end
	end
	resp.body = JSON.generate({ "status"=> status, "host" => host, "ports" => ports })
}

$types = {"id" => "int", "type"=> "int", "nas_id" => "int", "lid" => "int", "cid"=>"int", "session_start"=>"date", "session_time"=>"int", "from_number"=>"string", "to_number"=>"string", "h323_id"=>"string" }
$cmp = { "equal" => "=", "big" => ">" , "bigorequal" => ">=" , "small" => "<" , "smallorequal" => "<=" }	
$cmpstr = { "equalstr" => "=", "mask" => "LIKE", "regexp" => "REGEXP"}

server.mount_proc('/telephony'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()

	def filterValue(key,value,cmpval)
		# parse
		def parseDate(fmt,value)
			begin
				v = DateTime.strptime(value, fmt)
				v = v.to_time.to_i
			rescue => e
				p "Exception DateTime.strptime with format #{fmt} and value #{value}"
				p e
				v = nil
			end
			v
		end

		# if unknow type
		return nil if !$cmp.has_key?(cmpval) && !$cmpstr.has_key?(cmpval)

		type = $types[key]
		if type == 'int'
			begin
				v = Integer(value)	
			rescue
				return nil
			end
			return "#{key} #{$cmp[cmpval]} #{v}"
		elsif type == 'string'
			v = value.delete("'\"\\")
			return "#{key} #{$cmpstr[cmpval]} '#{v}'"
		elsif type == 'date'
			v = parseDate('%Y-%m-%d %H:%M:%S',value)
			return "#{key} #{$cmp[cmpval]} CONVERT_TZ(FROM_UNIXTIME(#{v}), 'SYSTEM', '+0:00')" if v != nil
			v = parseDate('%Y-%m-%d %H:%M',value)
			return "#{key} #{$cmp[cmpval]} CONVERT_TZ(FROM_UNIXTIME(#{v}), 'SYSTEM', '+0:00')" if v != nil
			v = parseDate('%Y-%m-%d',value)
			return "#{key} #{$cmp[cmpval]} CONVERT_TZ(FROM_UNIXTIME(#{v}), 'SYSTEM', '+0:00')" if v != nil
		end
		return nil
	end

	# sorting
	sqlparams = []
#	order = Array.new
#	params['direction'] = 'asc' if params['direction'] != 'asc' && params['direction'] != 'desc'
	# from
#	if params['order'] != '' && params['order'] != nil
#		s = params['order'].split(',')	
#		s.each do |x|
#			order.push(x) if $types.has_key?(x)	
#		end
#	end


	# from
	if params['session_start_from'] == '' || params['session_start_from'] == nil
		current_time = DateTime.now
		params['session_start_from'] = current_time.strftime "%Y-%m-%d 00:00:00"
	end
	z = filterValue('session_start',params['session_start_from'],'bigorequal')
	sqlparams.push(z) if z != nil
	
	# to
	if params['session_start_to'] == '' || params['session_start_to'] == nil
		current_time = DateTime.now
		params['session_start_to'] = current_time.strftime "%Y-%m-%d 23:59:59"
	end
	z = filterValue('session_start',params['session_start_to'],'smallorequal')
	sqlparams.push(z) if z != nil

	order = Hash.new
	orderclass = Hash.new

	# defaulate order fields
	$types.each do |k,v|
		# if empty break
		order["#{k}_sort"] = ""
	end

	# create order array for sql request
	params.each do |k,v|
		r = k.scan(/_sort$/)
		# if comparator has
		next if r.length == 0 || v == ""
		# unknow key check
		n = k.gsub('_sort','')
		next if !$types.has_key?(n)
		# real var
		order[n] = ( v != 'asc' && v != 'desc' ? 'asc' : v)
		# make css 
		if  v == 'asc'
			orderclass[n] = 'glyphicon-triangle-top'
		elsif v == 'desc'
			orderclass[n] = 'glyphicon-triangle-bottom'
		else
			orderclass[n] = ''
		end
	end
	params['order'] = order
	params['orderclass'] = orderclass
	p orderclass

	# work with comparator fields
	params.each do |k,v|
		r = k.scan(/_comp$/)
		# if comparator has
		next if r.length == 0 || v == ""
		# real var
		n = k.gsub('_comp','')
		# if empty break
		next if params[n] == "" || params[n] == nil
		# filter
		z = filterValue(n,params[n],v)
		sqlparams.push(z) if z != nil
	end
	p sqlparams

	params['pagestart'] = 1 
	params['pageend'] = 1

	# pagesize
	if !params.has_key?("pagesize")
		params['pagesize'] = 500 
	else
		params['pagesize'].delete!("-")
	end
	
	# page
	if !params.has_key?("page")
		params['page'] = 1 
	else
		params['page'].delete!("-")
		# convert to integer because param string
		params['page'] = params['page'].to_i
	end

	params['all'] = 0
	r = dbm.countSessionLog(sqlparams,params['session_start_from'],params['session_start_to'])
	if  r != nil
		next if r.size == 0
		count = r.first['count(*)']
		params['all'] = count
		params['pageend']  = count.to_i / params['pagesize'].to_i
		params['pageend'] = params['pageend'] + 1 if ( count.to_i % params['pagesize'].to_i ) != 0
		params['pageend'] = 1 if params['pageend'].to_i == 0
		# reset page if change pagesize
		params['page'] = 1 if params['page'] > params['pageend']
		#
		list = dbm.querySessionLog(sqlparams, order, params['page'].to_i, params['pagesize'].to_i, params['session_start_from'], params['session_start_to'])
		next if list == nil
	end
	resp.body = (ERBContext.new({ "param" => { "query" => params , "list"=> list, "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./telephony.erb') 
}

server.mount_proc('/getvoiprequest') { |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()
	
	if params.has_key?("lr") && params.has_key?("date")
		lr = params["lr"].to_i
		date = params["date"]
		next if lr == 0
		begin
			v = DateTime.strptime(date, "%Y-%m-%d")
			newdate = v.strftime "%Y%m"
		rescue
			next
		end
		d = dbm.queryRequestLog(lr,newdate)
		status = ( d == nil ? 'fail' : 'ok'  )
		resp.body = JSON.generate({ "status"=> status, "info" => d.first })
	end
}	
server.mount_proc('/search'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()
	list = []
	modes = []
	p params
	if params.has_key?("access")
		modes.push("access")
	end
	if params.has_key?("hybrid")
		modes.push("hybrid")
	end
	if params.has_key?("trunk")
		modes.push("trunk")
	end
	if params.has_key?("vlan")
		vlans = params['vlan'].delete(" ").split(",")
		vlans.each do |vlan|
			tmplist = db.getSwitchPortsByVlan(vlan.to_i,modes)
			list = list.concat(tmplist)
		end
	end
	p list
	resp.body = (ERBContext.new({ "param" => { "vlan" => params['vlan'], "list"=> list, "modes" => modes , "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./search.erb') 
}
server.mount_proc('/routertune_getobjects'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	status = "error"
	reason = "not found param"
	params = req.query()	
	if params.has_key?("contract")
		contract = params['contract'].split("-")[0]	
	        p contract
		p "GetObjectRouter list"
		r = dbm.getObjectRouter(contract)
		#p r
		p r.size
		if r.size == 0	
			resp.body = JSON.generate({ "status"=> "error", "reason" => "No routers objects." })
			next	
		end
	        p "GetObjectPPPoE list"
		x = dbm.getObjectPPPoE(contract)
		#p x
		if x.size == 0		
			resp.body = JSON.generate({ "status"=> "error", "reason" => "No pppoe objects." })
			next	
		end
		reason = ""	
		status = "ok"
	end

	resp.body = JSON.generate({ "status"=> status, "reason" => reason, "pppoes" => x.to_a , "routers" => r.to_a })
}
server.mount_proc('/routertune_gendocx'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	
	params = req.query()	
	status = "error"
	reason = "some params not passed"
	if params.has_key?("routerid") && params.has_key?("contract")
		contract = params['contract'].split("-")[0]	
		
		r = dbm.getObjectRouterById(params['routerid'].to_i)
		next if r.size == 0		
		r = r.first

		s = r['url'].scan(/:\/\/(.*?):(.*?)@/)
		if s.length > 0
			login = s[0][0]
			pass = s[0][1]
			template = Sablon.template(File.expand_path("./template/template.docx"))
			context = {
			  login: login, 
			  password: pass,
			  ssid: r['ssid'],
			  psk: r['psk']
			}
			template.render_to_file File.expand_path("./www/out/#{contract}.docx"), context
			status = "ok"
			reason = "files/out/#{contract}.docx"
		else
			reason = "no found managment url"
		end

	end
	resp.body = JSON.generate({ "status"=> status, "reason" => reason  })
}	
server.mount_proc('/routertune'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()	
	uri = URI("http://192.168.2.79:8081/getRouterModules")                                                          
	http = Net::HTTP.new('192.168.2.79', 8081) 
	request = Net::HTTP::Get.new(uri.request_uri)                                          
	request['User-Agent'] = 'Mozilla/5.0'                                                  
	response = http.request(request)                                                      
	p response
	json = JSON.parse(response.body)
	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl, "modules" => json['modules'] }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./routertune.erb') 
}
server.mount_proc('/routertune_start'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	params = req.query()	
	status = "error"
	reason = "some params not passed"
	if params.has_key?("pppoeid") && params.has_key?("routerid") && params.has_key?("host")
	        p "GetObjectRouter"
		r = dbm.getObjectRouterById(params['routerid'].to_i)
		next if r.size == 0		
		r = r.first	
		p r	
	        p "GetObjectPPPoE"
		x = dbm.getObjectPPPoEById(params['pppoeid'].to_i)
		if x.size > 1 || x.size == 0
			p "PPPoE Object not found or more then 1."
			reason = "PPPoE Object not found or more then 1."
			resp.body = JSON.generate({ "status"=> status, "reason" => reason })
			next	
		end
		x = x.first
		p x
		n = r['url'].scan(/:\/\/([a-zA-Z0-9]+):([a-zA-Z0-9]+)@/)
		if n.length == 0
			p "Failed mgmt url parse."
			reason = "Failed mgmt url parse."
			resp.body = JSON.generate({ "status"=> status, "reason" => reason })
			next
		end	
		n=n[0]
		mgmt_login = n[0]
		mgmt_password = n[1]

		uri = URI("http://192.168.2.79:8081/syncRouter?handleTemplate=#{params['handleTemplate']}&internet_login=#{x['login']}&internet_password=#{x['password']}&mgmt_login=#{mgmt_login}&mgmt_password=#{mgmt_password}&ssid=#{r['ssid']}&psk=#{r['psk']}&host=0.0.0.0&module=#{params['module']}")                                                          
		http = Net::HTTP.new('192.168.2.79', 8081) 
                request = Net::HTTP::Get.new(uri.request_uri)                                          
                request['User-Agent'] = 'Mozilla/5.0'                                                  
                #request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' 
                #request['Accept-Encoding'] = 'gzip, deflate'                                          
                #request['Accept-Language'] = 'ru-RU,ru;q=0.8,en-US;q=0.5,en;q=0.3'                    
                #request['Connection'] = 'keep-alive'                                                  
                #request['Upgrade-Insecure-Requests'] = '1'                                            
                #request.basic_auth("admin", "admin")                                                  
                response = http.request(request)                                                      
		output = response.body                                                         
		json = JSON.parse(response.body)
		reason = json['reason']
		status = "ok"
	end

	resp.body = JSON.generate({ "status"=> status, "reason" => reason })
}	
server.mount_proc('/geo'){ |req, resp|
	resp['Content-Type'] = 'text/html'

	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./geo.erb') 
}	
server.mount_proc('/geolist'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	list = db.geoList()
	status = "ok"
	resp.body = JSON.generate({ "status"=> status, "geolist" => list })
}

server.mount_proc('/geosave'){ |req, resp|
	resp['Content-Type'] = 'text/html'

	jstr = req.body()
	json = JSON.parse(jstr)

	r = true
	if json['list'] != nil 
		if json['list'].instance_of?(Array)
			db.transaction do
				json['list'].each do |x|
					if x['host'] != nil && x['address'] != nil && x['latitude'] != nil && x['longitude'] != nil
						p x
						r = db.setHostGeoData(x['host'],x['address'],x['latitude'],x['longitude'])
						#break if !r 
					end
				end
			end
		end
	end

	status = (r) ? "ok" : "fail";
	resp.body = JSON.generate({ "status"=> status })
}

server.mount_proc('/visual'){ |req, resp|
	resp['Content-Type'] = 'text/html'

	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./visual.erb') 
}	
server.mount_proc('/d3tree'){ |req, resp|
	resp['Content-Type'] = 'text/html'

	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  } })).renderWithLayout("#{$rootpath}/template/templ.erb",'./d3tree.erb') 
}	

server.mount_proc('/sql'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	idx = 0
	params = req.query()
	idx = params['idx'].to_i if params.has_key?("idx")
	reqlist = [
		{ "desc" => "Найти access порты где больше 1 мака.",
		  "sql" => "select z.* from (select a.host as host,a.hostname as hostname,b.port as port,c.mode as mode,COUNT(DISTINCT(b.mac)) AS num from hosts as a inner join macs as b on a.id = b.hostid and b.vlan = @vlan inner join ports as c on c.hostid = a.id and c.port = b.port group by b.port,a.host order by a.host) AS z where  z.num>1 and mode != 'trunk'  and port not like '%25%' and port not like '%26%' and port not like '%27%' and port not like '%28%' and port not like '%1/1%' and port not like '%2/1%'",
		  "params" => { "vlan" => "65" }
		},
		{ "desc" => "Найти мак на access портах в vlan.",
		  "sql" => 'select b.host,a.port from macs as a inner join hosts as b on a.hostid = b.id inner join ports as c on b.id = c.hostid and c.port = a.port where c.mode != "trunk" and a.mac="@mac" and a.vlan=@vlan',
		  "params" => { "vlan" => "65", "mac" => "" }
		},
		{ "desc" => "Найти совпадающие маки на access портах.",
		  "sql" => "select a.port,a.mac,b.host
				from macs as a 
				inner join hosts as b on a.hostid = b.id 
				inner join ports as c on b.id = c.hostid and c.port = a.port 
				inner join (
					select n.mac AS mac from (
						select a.mac AS mac, count(a.port) AS portcnt
						from macs as a 
						inner join hosts as b on a.hostid = b.id 
						inner join ports as c on b.id = c.hostid and c.port = a.port 
						where a.vlan = @vlan and c.mode != 'trunk' and b.host not in ('192.168.1.1','192.168.1.2') and a.port != '1/1' and a.port != '2/1'
						group by a.mac 
					) as n where portcnt > 1
				) as d on d.mac = a.mac
				where a.vlan = @vlan and c.mode != 'trunk' and b.host not in ('192.168.1.1','192.168.1.2') and a.port != '1/1' and a.port != '2/1'
				order by a.mac",
		  "params" => { "vlan" => "65" }
		},
		{ "desc" => "Найти по description PORT.",
		  "sql" => "select a.host,a.hostname,b.port,b.desc,b.untagged,b.tagged from hosts as a inner join ports as b on a.id = b.hostid where b.desc like '%@desc%'",
		  "params" => { "desc" => "" }
		},
		{ "desc" => "Найти по description VLAN.",
		  "sql" => "select a.host,b.desc,b.tag from hosts as a inner join vlans as b on a.id = b.hostid where b.desc like '%@desc%'",
		  "params" => { "desc" => "" }
		},
#		{ "desc" => "Детальные mac-hash-collision колиизии на QSW2800.",
#		  "sql" => "select a.host,a.hostname,b.mac,b.vlan,b.count from hosts as a inner join collisions as b on a.id = b.hostid order by a.host, b.count desc",
#		  "params" => { }
#		},
#		{ "desc" => "Общие mac-hash-collision колиизии на QSW2800.",
#		  "sql" => "select a.host,a.hostname,b.mac,b.vlan,sum(b.count) from hosts as a inner join collisions as b on a.id = b.hostid group by a.host",
#		  "params" => { }
#		}, 
		{ "desc" => "Статистика попыток переподключения PPPOE.",
		  "sql" => "select cid,mac,host,port,vlan,attempts from clients order by attempts desc",
		  "db" => "billing",
		  "params" => { }
		},
		{ "desc" => "Поиск trunk портов 100Mbit/s",
		  "sql" => "select a.host,a.hostname,b.port,b.desc,b.mode,b.tagged,b.untagged,b.state,b.speed from hosts as a inner join ports as b on a.id = b.hostid where b.mode = 'trunk' and b.speed = 100 and ( b.desc like '%101%' or b.desc like '%100%' ) ",
		  "params" => {}
		},
		{ "desc" => "Поиск vlan на порту включая диапазоны (ex:2-4094).",
		  "sql" => "select a.host,a.hostname,a.model,b.desc,b.mode,b.tagged,b.untagged from hosts as a inner join ports as b on a.id = b.hostid inner join port_vlan_range as c on b.portid = c.portid where c.mode in (@mode) and c.low <= @vlan and c.high >= @vlan",
		  "params" => { "vlan" => "3", "mode" => "1,0" },
		  "comment" => "mode: 0 = TRUNK, 1 = ACCESS"
		},
		{ "desc" => "Поиск vlan на порту не включая диапазоны.",
		  "sql" => "select a.host,a.hostname,a.model,b.desc,b.mode,b.tagged,b.untagged from hosts as a inner join ports as b on a.id = b.hostid inner join port_vlan_range as c on b.portid = c.portid where c.mode in (@mode) and c.low = @vlan and c.high = @vlan",
		  "params" => { "vlan" => "3", "mode" => "1,0" },
		  "comment" => "mode: 0 = TRUNK, 1 = ACCESS"
		}

	]

	table = []
	if params.has_key?("sql")
		sql = params['sql']	
		reqlist[idx]['params'].each do |k,v|
			sql.gsub!("@#{k}",( params.has_key?(k) ? params[k] : v ))
		end
		if reqlist[idx].has_key?("db")
			# if billing database
			table = dbbl.db.execute(sql)
			p table
		else
			table = db.db.execute(sql)
		end
	end

	resp.body = (ERBContext.new({ "param" => { "reqlist" => reqlist, "idx" => idx, "table" => table, "baseurl" => baseurl }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./sql.erb') 
}	
server.mount_proc('/searchport'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./searchport.erb') 
}	
server.mount_proc('/diagport'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./diagport.erb') 
}	
server.mount_proc('/amqp'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  }})).renderWithLayout("#{$rootpath}/template/templ.erb",'./amqp.erb') 
}	
server.mount_proc('/tasks'){ |req, resp|
	resp['Content-Type'] = 'text/html'
	resp.body = (ERBContext.new({ "param" => { "baseurl" => baseurl  } })).renderWithLayout("#{$rootpath}/template/templ.erb",'./tasks.erb') 
}	


#
# websocket
#

class WebSocketService < WEBrick::Websocket::Servlet
	
	def select_protocol(available)
		# method optional, if missing, it will always select first protocol.
		# Will only be called if client actually requests a protocol
		#pwarn "SELECT PROTOCOL !"
		#available.include?('myprotocol') ? 'myprotocol' : nil
		nil
	end

	def socket_open(sock)
		# optional
		#sock.puts "Wait action\n" # send a text frame
		pwarn "Socket open #{sock}"
	end

	def socket_close(sock)
		pwarn "Socket close #{sock}"
		$wsapi.close(sock)
	end

	def socket_text(sock, text)
		#puts "recv json #{text}"
		json = JSON.parse(text)
		$wsapi.call(sock,json)
	end
end

server.mount('/websocket', WebSocketService)

trap('INT') { server.stop }
server.start

exit

