require_relative 'templates/qtech29_template.rb'

class Qtech29 < Qtech29Template

	def initialize(mexp)
		super(mexp)
		slf = self	
		@broadcast_enable=false
		@trunknames = [ "1/1" , "2/1" ]
		@broadcastLimitAccess = "1/16"
		@broadcastLimitTrunk = "1/16"
		
		mexp.templates("ifacerange") do 
			expect(/interface range ([a-z0-9\/\s]+)\n/) do |x|
				pinfo "Range #{x[1]}"
				slf.curiface = slf.qtech29_expand_range(x[1])
				slf.set_option("ports",slf.curiface,nil,nil)
				each("ifaceopts")
			end
		end
	end
	def getAbsolutePort(port)
		if x = port.match(/0\/([0-9]+)/)
			return x[1]
		end
		if x = port.match(/1\/1/)
			return "25"
		end
		if x = port.match(/2\/1/)
			return "26"
		end
		return port
	end
	def qtech29_expand_range(range)
		p range
		ranges = range.gsub("ethernet ","").gsub(" to ","-").gsub("0/","").gsub("1/1","25").gsub(/2\/1/,"26").gsub(" ",",").strip()
		p ranges
		r = expand_range(ranges)
		o = Array.new
		r.each do |k|
			if k.to_i <= 24 
				o.push("0/#{k}")
			elsif k.to_i == 25 
				o.push("1/1")
			elsif k.to_i == 26
				o.push("2/1")
			end
		end
		o
	end
	
	def setBroadcastStormEnable(speed)
		slf = self
		if !@broadcast_enable
			@me.send("storm-control ratio #{speed}\n")
			@me.send("storm-control type broadcast\n")
			self.wait(/\(config/)
			@broadcast_enable=true
		end
	end
	def setBroadcastStorm(port,speed)
		slf = self
		self.setBroadcastStormEnable(speed)
		@me.send("int e #{port}\n")
		@me.send("storm-control\n")
		@me.send("exit\n")
		self.wait(/\(config/)
	end
end

