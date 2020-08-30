require 'sqlite3'

class DbBilling

	attr_accessor :db

	def initialize
		begin
			@c = 0
			@db = SQLite3::Database.new "#{$rootpath}/db/billing.db" #":memory:"
			@db.results_as_hash = true
			# hosts
			@db.execute "CREATE TABLE IF NOT EXISTS clients (
					cid INTEGER,
					mac VARCHAR(14),
					host VARCHAR(15) DEFAULT '',
					port VARCHAR(20) DEFAULT '',
					vlan INTEGER,
					state INTEGER DEFAULT 0,
					updatetime INTEGER DEFAULT 0,
					attempts INTEGER DEFAULT 0,
					PRIMARY KEY(cid,mac))"
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

	#
	# Client work
	#
	def pushClient(cid,mac,host,port,vlan,state)
		vlan = 0 if vlan == nil
		@db.execute "REPLACE INTO clients VALUES(#{cid},'#{mac}','#{host}','#{port}',#{vlan},#{state},#{Time.now.to_i},1)"
	end

	#
	# State 0 - not found, 1 - pushed sqlite , 2 - pushed wsdl
	#
	def setClientStatus(cid,mac,state)
		@db.execute "UPDATE clients SET state=#{state} WHERE mac='#{mac}' AND cid='#{cid}'"
	end

	def increaseClientAttempts(cid,mac)
		@db.execute "UPDATE clients SET attempts=attempts+1 WHERE mac='#{mac}' AND cid=#{cid}"
	end
	def getClientByCidMac(cid,mac)
		@db.get_first_row "SELECT * FROM clients WHERE cid = #{cid} AND mac = '#{mac}'"
	end

	def getClients()
		@db.execute "SELECT * FROM clients"
	end
	
	def getClientsNotFound()
		@db.execute "SELECT * FROM clients WHERE state=0 and host='' "
	end
	
	def getClientsFoundNotReady()
		@db.execute "SELECT * FROM clients WHERE state=1 "
	end

end

