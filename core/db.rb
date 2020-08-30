require 'sqlite3'

class Db

	attr_accessor :macport
	attr_accessor :arp
	attr_accessor :names
	attr_accessor :c
	attr_accessor :db

	TAGGED = 0
	UNTAGGED = 1

	def initialize
		begin
			@c = 0
			@db = SQLite3::Database.new "#{$rootpath}/db/database.db" #":memory:"
			@db.results_as_hash = true
			#puts $db.get_first_value 'SELECT SQLITE_VERSION()'
			#$db = SQLite3::Database.open "test.db" #":memory:"
			# hosts
			@db.execute "CREATE TABLE 
					IF NOT EXISTS hosts(
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					host VARCHAR(15),
					mac VARCHAR(14),
					services VARCHAR(20),
					hostname VARCHAR(100),
					model VARCHAR(50),
					upportext INTEGER,
					upportslf INTEGER)"
			# update hosts
			@db.execute "CREATE TABLE 
					IF NOT EXISTS updatehosts(
					host VARCHAR(17),
					PRIMARY KEY(host))"
			# ports
			@db.execute "CREATE TABLE 
					IF NOT EXISTS ports(
					portid INTEGER PRIMARY KEY AUTOINCREMENT,
					hostid INTEGER,
					port VARCHAR(20),
					desc VARCHAR(50) DEFAULT '',
					mode VARCHAR(20) DEFAULT '',
					tagged TEXT DEFAULT '',
					untagged TEXT DEFAULT '', 
					state INTEGER,
					speed INTEGER,
					rate_rx integer, 
					rate_tx integer,	
					UNIQUE(hostid,port))"
			# macs
			@db.execute "CREATE TABLE 
					IF NOT EXISTS macs(
					hostid INTEGER,
					mac VARCHAR(17),
					port VARCHAR(20),
					vlan INTEGER,
					PRIMARY KEY(hostid,mac,port,vlan))"
			# collisions
			@db.execute "CREATE TABLE 
					IF NOT EXISTS collisions(
					hostid INTEGER,
					mac VARCHAR(17),
					vlan INTEGER,
					count INTEGER,
					PRIMARY KEY(hostid,mac,vlan,count))"
			# vlans
			@db.execute "CREATE TABLE 
					IF NOT EXISTS vlans(
					hostid INTEGER,
					tag INTEGER,
					desc VARCHAR(100),
					PRIMARY KEY(hostid,tag))"
			# geo
			@db.execute "CREATE TABLE 
					IF NOT EXISTS geo(
					host VARCHAR(15),
					latitude FLOAT,
					longitude FLOAT,
					address TEXT,
					PRIMARY KEY(host))"
			# port_vlan_range
			@db.execute "CREATE TABLE 
					IF NOT EXISTS port_vlan_range (
					portid INTEGER,
					mode INTEGER,
					low INTEGER,
					high INTEGER,
					PRIMARY KEY(portid,mode,low,high))"
		rescue SQLite3::Exception => e 
			fexcept(e,'db:constructor')
		end
	end

	def transaction(mark='',&block)
		begin
			@db.transaction(:immediate) do
				block.call
			end
		rescue SQLite3::Exception => e 
			fexcept(e,mark)	
		end
	end
	
	def close()
		@db.close()
	end 


	#
	# geo
	#
	def geoList
		r = @db.execute "SELECT *,h.host as host FROM hosts as h LEFT OUTER JOIN geo AS g ON h.host = g.host LEFT OUTER JOIN ports as p ON p.hostid = h.id AND p.portid = h.upportslf"
		r.each do |x|
			z = @db.execute "SELECT p.port AS port,h.host AS host FROM ports as p INNER JOIN hosts AS h ON p.portid = h.upportext WHERE p.hostid=#{x['id']}"
			x['plist'] = z
		end
	end

	def setHostGeoData(host,address,latitude,longitude)
		@db.execute("REPLACE INTO geo VALUES ('#{host}',#{latitude},#{longitude},'#{address}')")
	end

	#
	# update hosts
	#
	def deleteAllUpdateHosts
		@db.execute "DELETE FROM updatehosts"
	end

	def insertUpdateHost(host)
		@db.execute "REPLACE INTO updatehosts VALUES ('#{host}')"
	end

	def getUpdateHosts()
		@db.execute("SELECT * from hosts WHERE host IN (SELECT * FROM updatehosts)")
	end

	def getHostsNoRetreivedMacs()
		@db.execute("SELECT * FROM hosts WHERE host NOT IN (SELECT a.host FROM hosts AS a INNER JOIN macs AS b ON a.id = b.hostid GROUP BY a.host)")	
	end

	#
	# ports
	#
	
	def deleteAllPorts
		@db.execute "DELETE FROM ports"
	end
	def setPortRate(hostid,port,raterx,ratetx)
		@db.execute "UPDATE ports 
				SET rate_rx=#{raterx},
				rate_tx=#{ratetx}
				WHERE port='#{port}' AND hostid = '#{hostid}'"
	end
	def setPortVlanRanges(portid,mode,low,high)
			@db.execute "REPLACE INTO port_vlan_range
					(portid,mode,low,high) 
					VALUES (#{portid},#{mode},#{low},#{high})"
			return @db.last_insert_row_id
	end
	def setPortInfo(hostid,port,desc,mode,untagged,tagged)
		untagged =  untagged == nil  ? Array.new : untagged
		tagged =  tagged == nil ? Array.new : tagged
		r = @db.get_first_row "SELECT * FROM ports WHERE port='#{port}' AND hostid = '#{hostid}'"
		desc = desc.delete("\'\"") if desc != nil
		if r != nil 
			@db.execute "UPDATE ports 
					SET desc='#{desc}',
					mode='#{mode}',
					untagged='#{untagged.join(",")}',
					tagged='#{tagged.join(",")}' 
					WHERE port='#{port}' AND hostid = '#{hostid}'"
			p r
			return r['portid']
		else
			@db.execute "INSERT INTO ports 
					(hostid,port,desc,mode,untagged,tagged) 
					VALUES (#{hostid},'#{port}','#{desc}','#{mode}','#{untagged.join(",")}','#{tagged.join(",")}')"
			return @db.last_insert_row_id
		end
	end
	def setPortState(hostid,port,state,speed)
		state = 1 if state == 'UP'
		state = 0 if state == 'DOWN'
		state = 2 if state == 'A-DOWN'
		speed = 0 if speed == nil
		r = @db.get_first_row "SELECT * FROM ports WHERE port='#{port}' AND hostid = '#{hostid}'"
		if r != nil 
			@db.execute "UPDATE ports 
					SET 
					state=#{state},
					speed=#{speed} 
					WHERE port='#{port}' AND hostid = '#{hostid}'"
		else
			@db.execute "INSERT INTO ports 
					(hostid,port,state,speed) 
					VALUES (#{hostid},'#{port}',#{state},#{speed})"
		end
	end
	def getPorts(hostid)
		@db.execute "SELECT * FROM ports WHERE hostid=#{hostid}"
	end

	def getPortsWithSwitchs(addr)
		@db.execute "select b.port as port,c.host as switch,c.mac as mac from hosts as a inner join ports as b on a.id = b.hostid inner join hosts as c on b.portid = c.upportext where a.host='#{addr}'"
	end

	def getSwitchUplinkPort(addr)
		@db.get_first_row "select b.port,a.services from hosts as a inner join ports as b on a.upportext = b.portid where host = '#{addr}'"
	end

	def getSwitchPortInfo(host,port)
		@db.get_first_row "select b.* from hosts as a inner join ports as b on b.hostid = a.id where a.host='#{host}' and b.port = '#{port}';"		
	end

	#
	# macs
	#
	def deleteAllMac()
		@db.execute "DELETE FROM macs"
	end

	def insertMac(vlan,id,mac,port)
		@db.execute "REPLACE INTO macs (hostid,mac,port,vlan) VALUES ('#{id}','#{mac}','#{port}',#{vlan.to_i})"
	end
	def insertCollision(id,mac,vlan,count)
		@db.execute "REPLACE INTO collisions (hostid,mac,vlan,count) VALUES ('#{id}','#{mac}',#{vlan.to_i},#{count.to_i})"
	end

	#
	# hosts
	#
	def deleteHostByMac(mac)
		@db.execute "DELETE FROM hosts WHERE mac='#{mac}'"
	end
	def addHostMac(host,mac)
		@db.execute "REPLACE INTO hosts (host,mac) values ('#{host}','#{mac}')"
		return @db.last_insert_row_id 
	end
	def setHostForMac(host,mac)
		@db.execute "UPDATE hosts SET host = '#{host}' WHERE mac = '#{mac}'"
		return @db.last_insert_row_id 
	end
	def setMacForHost(host,mac)
		@db.execute "UPDATE hosts SET mac = '#{mac}' WHERE host = '#{host}'"
		return @db.last_insert_row_id 
	end
	def setMacForHostid(hostid,mac)
		@db.execute "UPDATE hosts SET mac = '#{mac}' WHERE id = '#{hostid}'"
		return @db.last_insert_row_id 
	end
	def setHostname(hostid,hostname)
		@db.execute "UPDATE hosts SET hostname = '#{hostname}' WHERE id = '#{hostid}'"
	end
	def setModel(hostid,model)
		@db.execute "UPDATE hosts SET model = '#{model}' WHERE id = '#{hostid}'"
	end
	def clearAllHostUplinks
		@db.execute "UPDATE hosts SET upportslf=0,upportext=0"
	end
	def setHostServices(host,services)
		r = @db.get_first_row "SELECT * FROM hosts WHERE host='#{host}'"
		id = nil
		if r == nil
			@db.execute "INSERT INTO hosts (host,services)
				VALUES ('#{host}','#{services}')"
			id = @db.last_insert_row_id
		else
			@db.execute "UPDATE hosts SET services='#{services}' 
				WHERE host='#{host}'"
			id = r['id']
		end
		return id
	end
	def getHostsWithServices()
		# Find a few rows
		p @db
		@db.execute("SELECT * from hosts WHERE services != '' ")
	end
	def getHostsWithoutMacs()
		@db.execute("SELECT * from hosts where mac is null")
	end
	def getHosts()
		@db.execute("SELECT * from hosts")
	end
	def getHostsAndMacs(vlan)
		@arp = Hash.new
		@macport = Hash.new
		@names = Hash.new
		# Find a few rows
		@db.execute("SELECT * FROM hosts") do |rowh|
			# Find a few rows
			#p rowh
			host = rowh['host']
			mac = rowh['mac']
			@arp[mac] = host
			@macport[mac] = Hash.new
			@names[mac] = rowh['hostname']
			@db.execute("SELECT * FROM macs WHERE hostid=#{rowh['id']} AND vlan IN (#{vlan})") do |rowm|
 			#	p rowm if mac == '1c:bd:b9:9c:02:44'
				@c = @c + 1
				port = rowm['port']
				extmac = rowm['mac']
				if port != 'cpu' && port != 'CPU'
					if !@macport[mac].has_key?(port)
						@macport[mac][port] = Array.new
					end
					@macport[mac][port].push(extmac)
				end
			end			
		end
		p "Count #{@c}"
		return @arp,@macport,@names
	end

	def getHost(host)
		@db.get_first_row "SELECT * FROM hosts WHERE host='#{host}'"
	end

	def getUnknowHostByMac(mac)
		@db.get_first_row "SELECT * FROM hosts WHERE mac='#{host}' and host like '%unknow%'"
	end
	
	def getUnknowHosts()
		@db.execute "SELECT * FROM hosts WHERE host like '%unknow%'"
	end

	#
	# Vlans
	#

	def deleteAllVlan()
		@db.execute "DELETE FROM vlans"
	end

	def getHostVlanByName(host,name)
		@db.get_first_row("select b.tag from hosts as a inner join vlans b on a.id = b.hostid where a.host='#{host}' and b.desc='#{name}'")
	end

	def insertVlan(hostid,tag,desc)
		desc = desc.delete("\'\"") if desc != nil
		@db.execute "REPLACE INTO vlans(hostid,tag,desc) 
				VALUES (#{hostid},#{tag},'#{desc}')"
	end

	def getSwitchPortsByVlan(vlan,modes)
		tmpmodes = modes.collect.with_index do |x,i|
			"'#{x}'"
		end
		lstmodes = tmpmodes.join(",")
		r = @db.execute "SELECT * FROM hosts as h 
					INNER JOIN ports as p ON h.id = p.hostid 
					WHERE ( 
					p.untagged like '%,#{vlan},%'
					OR p.untagged like '%,#{vlan}'
					OR p.untagged like '#{vlan},%'
					OR p.untagged like '#{vlan}'
					OR p.tagged like '%,#{vlan},%'
					OR p.tagged like '%,#{vlan}'
					OR p.tagged like '#{vlan},%'
					OR p.tagged like '#{vlan}')
					AND p.mode IN (#{lstmodes})"
		r
	end

	#
	# Mapping 
	#

	def getSwitchOnPort(host,port)

		result=nil
		@db.execute("SELECT * FROM hosts WHERE host='#{host}'") do |rowh|
			#p rowh

			@db.execute("SELECT * FROM ports WHERE port='#{port}' and hostid=#{rowh['id']}") do |rowp|
				#p rowp
				
				@db.execute("SELECT * FROM hosts WHERE upportext=#{rowp['portid']}") do |row|
					#p row
					result = row['host']		
				end
			end
		end
		return result
	end

	def putMapHash(hash,portid,arp)
		hash.each do |mac,hports|
			hostid = nil
			if arp.has_key?(mac)
				host = arp[mac]
				@db.execute "UPDATE hosts SET 
						upportext='#{portid}',
						upportslf=NULL 
						WHERE host='#{host}'"
				r = @db.get_first_row "SELECT id FROM hosts 
							WHERE host='#{host}'"
				hostid = r['id']
			else
				# create unknow ip mac
				hostid = setHostServices('unknow','')
				pwarn "Create unknow #{hostid} mac #{mac}",0
				setMacForHostid(hostid,mac)
				# update upportext
				@db.execute "UPDATE hosts SET
						host='unknow_ip_id#{hostid}',
						upportext='#{portid}',
						upportslf=NULL 
						WHERE id='#{hostid}'"
			end
			#p mac
			#p host
			hports.each do |port,hmacs|
				#p "HPort #{port} "
				# check if port exist
				r = @db.get_first_row "SELECT * FROM ports 
							WHERE port='#{port}' AND hostid='#{hostid}'"
				portid = nil
				# if dont
				if r == nil
					@db.execute "INSERT INTO ports (hostid,port) 
							VALUES (#{hostid},'#{port}')"
					portid = @db.last_insert_row_id
				else
					portid = r['portid']
				end
				# if macs nils
				if hmacs == 'UPLINK'
					# set as self uplink 
					@db.execute "UPDATE hosts SET upportslf=#{portid} WHERE id=#{hostid}"
				else
					# pass to work next for port
					putMapHash(hmacs,portid,arp)
				end
			end
		end
	end

	def getMapHash(portid)
		hash = nil
		@db.execute("SELECT * FROM hosts WHERE upportext=#{portid}") do |rowh|
			mac = rowh['mac']
			hash = { mac => Hash.new }
			@db.execute("SELECT * FROM ports WHERE hostid=#{rowh['id']} ORDER BY portid") do |rowp|
				portidnew = rowp['portid']
				port = rowp['port']
				if portidnew == rowh['upportslf']
					hash[mac][port] = 'UPLINK'
				else
					# если не чо не найдет вернет nil
					z = getMapHash(portidnew)
					hash[mac][port] = z
					
				end
			end
		end
		return hash
	end

end

