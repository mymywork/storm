#!/usr/bin/ruby
require 'rubygems'

class Protocols < ParamFilter

	def proto_telnet_options_neogotiate(slf,buffer)
		#p "Telnet"
		buf = buffer.unpack('C*')
		answer = []
		i = 0
		s1 = 0
		s2 = 0
		while i < buf.length
			#pwarn "i=#{i}"
			#pwarn "buf[#{i}] = #{buf[i]}"
			if buf[i] == 0xff 
				#pwarn buf
				s1 = i
				i = i + 1
				# NOT SUPPORT SUBNEOGATION OPTION !!!
				if i < buf.length && ( buf[i] == 253 || buf[i] == 251 || buf[i] == 252 || buf[i] == 254 )
					#pwarn "buf[#{i}] = #{buf[i]}"
					i = i + 1
					if i < buf.length && buf[i] > 0 && buf[i] < 49
						#pwarn "buf[#{i}] = #{buf[i]}"
						i = i + 1
						i = s1			# back in start  of buffer if we slice
						option = buf.slice(s1,3)

						if option[1] == 253	#DO
							option[1] = 252	#WONT
							answer = answer.concat(option)
						elsif option[1] == 251	#WILL
							option[1] = 254	#DONT
							answer = answer.concat(option)
						elsif option[1] == 254 || option[1] == 252

						elsif option[1] == 250 || option[240]
							p "Subnegotiation option"
						else
							p "Exception telnet option #{option[1]}"
						end

						buf.slice!(s1,3)
						#p "after buf slice #{s1} len=3"
						#p buf
					end
				end
			else
				i = i + 1
			end
		end
		if answer.size != 0
			send(answer.pack('C*'))
		end
		buf.pack('C*')
	end

	
	def proto_option_b(slf,buf)
		x=buf.scan(/([\b]+)/)
		x.each do |z|
		#	p z
			z = z[0]
			n = buf.index(z)
			p = n - z.length	
			if p < 0 
				p = 0
				s = n + z.length
			else
				s = z.length * 2
			end
			buf.sub!(buf.slice(p,s),'')
		end
		buf
	end
end
