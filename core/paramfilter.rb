#!/usr/bin/ruby
require 'rubygems'

class ParamFilter

	def set_option(hash,key,option,value)
		if key.instance_of? Array
			key.each do |k|
				set_option_ex(hash,k,option,value)
			end
		else
			set_option_ex(hash,key,option,value)
		end

	end
	def set_option_ex(hash,key,option,value)
		# create list
		if !self.list.has_key?(hash)
			self.list[hash] = Hash.new
		end
		if !self.list[hash].has_key?(key)
			self.list[hash][key] = Hash.new
		end
		# create list option
		if option != nil
			# call local, global	
			r = call_setter("setter_#{hash}_#{option}",hash,key,option,value)
			if r == false
				r = call_setter("setter_global_#{option}",hash,key,option,value)
			end
		elsif option == nil && value != nil
			self.list[hash][key] = value
		end
	end

	def call_setter(name,hash,key,option,value)
		begin
			f = self.method(name)
			old = self.list[hash][key][option]
			self.list[hash][key][option] = f.call(key,old,value)
			return true
		rescue
			self.list[hash][key][option] = value
			return false
		end
	end

	#
	# Options handlers
	#
	

	def setter_ports_desc(port,src,dst)
		dst.strip
	end
	def setter_ports_mode(port,src,dst)
		if src != "trunk"
			return dst
		end
		src
	end
	def setter_ports_untagged(port,src,dst)
		pinfo "UNTAGGED  port=#{port} pre=#{src} add=#{dst}"
		tmp = src.to_a
		dst.each do |item|
			#tmp = tmp | self.expand_range(item)
			tmp = tmp | [item]
		end
		if tmp.count > 1 && tmp.index("all") != nil 
			tmp.delete("all")
		end
		tmp
	end
	def setter_ports_tagged(port,src,dst)
		pinfo "TAGGED  port=#{port} pre=#{src} add=#{dst}"
		tmp = src.to_a 
		dst.each do |item|
			#tmp = tmp | self.expand_range(item)
			tmp = tmp | [item]
		end
		if tmp.count > 1 && tmp.index("all") != nil 
			tmp.delete("all")
		end
		tmp
	end
	def setter_ports_status(port,pre,val)
		pdbg "set STATE  port=#{port} pre=#{pre} new-val=#{val}"
		if pre == nil || pre == "DOWN"
			return val
		end
		pre
	end
end
