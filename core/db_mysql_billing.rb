require 'mysql2'

class MysqlBillingTransport

	attr_accessor :db

	def initialize
		connect()
	end

	def connect
		begin
			@db = Mysql2::Client.new(:host => $db_billing_host, :username => $db_billing_login, :password => $db_billing_password, :database => $db_billing_database)	
		rescue => e
			p e
		end
	end

	def transaction(mark='',&block)
		begin
			block.call
		rescue => e 
		end
	end

	#
	# query
	#
	def countSessionLog(params,datefrom,dateto)
        	rnge = Array.new
	        (DateTime.strptime(datefrom,"%Y-%m-%d")..DateTime.strptime(dateto,"%Y-%m-%d")).map do |date|
			rnge.push(date.strftime("%Y%m"))
		end
		rnge = rnge.uniq
		sql = Array.new
		fields = "id,type,nas_id,lid,cid,session_start,session_time,round_session_time,from_number,to_number,dest_code,zone,min_cost,session_cost,oper_id,oper_round_session_time,oper_session_cost,sid,h323_id,dc,lr"
		rnge.each do |yearmonth|
			where = (params.length == 0 ? '' : "where #{params.join(' AND ')}" )
			sql.push("select #{fields} from log_session_6_#{yearmonth} #{where}")		
		end
		sqlstr = sql.join(' union ')
		sqlquery = "select count(*) from (#{sqlstr}) as a"
		p sqlquery

		begin
			return @db.query(sqlquery)		
		rescue => e
			connect()
			return @db.query(sqlquery)		
		end
	end

	def querySessionLog(params,order,from,count,datefrom,dateto)
        	rnge = Array.new
	        (DateTime.strptime(datefrom,"%Y-%m-%d")..DateTime.strptime(dateto,"%Y-%m-%d")).map do |date|
			rnge.push(date.strftime("%Y%m"))
		end
		rnge = rnge.uniq
		sql = Array.new
		fields = "id,type,nas_id,lid,cid,session_start,session_time,round_session_time,from_number,to_number,dest_code,zone,min_cost,session_cost,oper_id,oper_round_session_time,oper_session_cost,sid,h323_id,dc,lr"
		rnge.each do |yearmonth|
			where = (params.length == 0 ? '' : "where #{params.join(' AND ')}" )
			sql.push("select #{fields} from log_session_6_#{yearmonth} #{where}")		
		end
		sqlstr = sql.join(' union ')
		p sqlstr

		fieldsselect = "a.id as id, \
				case a.type when '1' then 'out' when '2' then 'in' else 'unknow' end as type, \
				concat(a.nas_id,' (',b.identifier,')') as nas_id,concat(a.lid,' (',c.login_alias,')') as lid,\
				concat(a.cid,' (',d.title,' : ',d.comment,')') as cid ,\
				a.session_start as session_start,\
				a.session_time as session_time,\ 
				a.round_session_time as round_session_time,\
				a.from_number as from_number,\
				a.to_number as to_number,\
				a.dest_code as dest_code,\
				a.zone as zone,\
				a.min_cost as min_cost,\
				a.session_cost as session_cost,\
				a.oper_id  as oper_id,\
				a.oper_round_session_time as oper_round_session,\
				a.oper_session_cost as oper_session_cost,\
				a.sid as sid,\
				a.h323_id as h323_id,\
				a.dc as dc,\
				a.lr as lr".gsub(/[\t\n\r]/,'')

		innerjoin = "inner join nas_6 as b on a.nas_id = b.id "
		innerjoin += "inner join user_alias_6 as c on a.lid = c.login_id "
		innerjoin += "inner join contract as d on a.cid = d.id "

		orderstr = ''
		orderarr = Array.new
		orderarr.push("a.session_start desc") if !order.has_key?("session_start")
		order.each do |k,v|
			orderarr.push("a.#{k} #{v}") if v != ""
		end

		orderstr =  " order by #{orderarr.join(',')} " if orderarr.length != 0

		sqlquery = "select #{fieldsselect} from (#{sqlstr}) as a  #{innerjoin} #{orderstr} limit #{(from.to_i-1)*count},#{count}"
		p sqlquery
		begin
			return @db.query(sqlquery)		
		rescue => e
			connect()
			return @db.query(sqlquery)		
		end
	end

	def queryRequestLog(lr,from)
		
		tmpsql = "select * from log_server_6_#{from} where id=#{lr}"
		p tmpsql
		begin
			return @db.query(tmpsql)		
		rescue => e
			connect()
			return @db.query(tmpsql)		
		end
	end

	# router tune
	#
	def getObjectRouter(contract)
		sql = " \
			select a.title as contract,a.comment as comment,b.id as objectid,c.value as url, d.value as ssid, e.value as psk \
			from contract as a \
			inner join object as b on b.cid = a.id and b.type_id = 18 \
			inner join object_param_value_text as c on c.param_id = 67 and c.object_id = b.id \
			inner join object_param_value_text as d on d.param_id = 110 and d.object_id = b.id \
			inner join object_param_value_text as e on e.param_id = 111 and e.object_id = b.id \
			where a.title like '#{contract}-%'"
		p sql
		begin
			return @db.query(sql)		
		rescue => e
			connect()
			return @db.query(sql)		
		end
	end

	def getObjectPPPoE(contract)
		sql = " \
		select b.id as objectid,a.title as contract,c.value as login, d.value as password  \
		from contract as a \ 
		inner join object as b on b.cid = a.id and b.type_id = 10 \
		inner join object_param_value_text as c on c.param_id = 13 and c.object_id = b.id \
		inner join object_param_value_text as d on d.param_id = 14 and d.object_id = b.id \
		where a.title like '#{contract}-%'"
		
		begin
			return @db.query(sql)		
		rescue => e
			connect()
			return @db.query(sql)		
		end
	end

	def getObjectRouterById(objectid)
		sql = " \
			select a.title as contract,a.comment as comment,b.id as objectid,c.value as url, d.value as ssid, e.value as psk \
			from contract as a \
			inner join object as b on b.cid = a.id and b.type_id = 18 \
			inner join object_param_value_text as c on c.param_id = 67 and c.object_id = b.id \
			inner join object_param_value_text as d on d.param_id = 110 and d.object_id = b.id \
			inner join object_param_value_text as e on e.param_id = 111 and e.object_id = b.id \
			where b.id = #{objectid}"
		begin
			return @db.query(sql)		
		rescue => e
			connect()
			return @db.query(sql)		
		end
	end

	def getObjectPPPoEById(objectid)
		sql = " \
		select b.id as objectid,a.title as contract,c.value as login, d.value as password  \
		from contract as a \ 
		inner join object as b on b.cid = a.id and b.type_id = 10 \
		inner join object_param_value_text as c on c.param_id = 13 and c.object_id = b.id \
		inner join object_param_value_text as d on d.param_id = 14 and d.object_id = b.id \
		where b.id = #{objectid}"
		
		begin
			return @db.query(sql)		
		rescue => e
			connect()
			return @db.query(sql)		
		end
	end

end

