#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'thread'
require_relative 'config.rb'

# level
$dbglevel = 20
$colored = true
$logprefix = "#{$rootpath}/log/"

class Debug

	def self.openFile(path)
		if Thread.current['io'] == nil
			Thread.current['io'] = Hash.new	
		end
		Thread.current['io'][path] = File.new("#{path}","a+") 
		Thread.current['io'][path]
	end
	
	def self.close(file)
		return if Thread.current["io"] == nil
		v = Thread.current["io"][file]
		if !v.closed? 
			v.close()
		end
	end

	def self.closeAll()
		return if Thread.current["io"] == nil
		Thread.current["io"].each do |k,v|
			if !v.closed? 
				v.close()
			end
		end
	end

	def self.setRedirectToLogging(path)
		Thread.current['stdtolog'] = path		
	end

	# pfile
	def self.pfile(str,path="default.log")
		begin
			prefix = $logprefix
			if Thread.current['io'] == nil
				Thread.current['io'] = Hash.new	
			end

			# if stdtolog redirect
			path = Thread.current['stdtolog'] if path == 'stdtolog'
			# if path nil set to default
			path = "#{prefix}default.log" if path == nil || path == false
			# if not full path add rootpath
			path = "#{prefix}#{path}" if path[0] != '.' && path[0] != '/'
			
			if path != nil && !Thread.current['io'].has_key?(path) 
				self.openFile(path)
			end
			Thread.current['io'][path].write("#{DateTime.now.strftime("%d/%m/%y %T")} #{str}")
			Thread.current['io'][path].fsync
		rescue => x
			p "Debug.pfile exception: #{x}"
		end
	end

	# red
	def self.pdbg(str,level=10)
		self.pfile "#{str}\n",'stdtolog' if Thread.current['stdtolog']
		return if level > $dbglevel
		if $colored 
			print "\e[31;1m[*] #{str}\e[0m\n"
		else
			print "[*] #{str}\n"
		end
	end

	# green
	def self.pinfo(str,level=10)
		self.pfile "#{str}\n",'stdtolog' if Thread.current['stdtolog']
		return if level > $dbglevel
		if $colored 
			print "\e[32;1m[*] #{str}\e[0m\n"
		else
			print "[*] #{str}\n"
		end
	end

	# purpule 
	def self.pwarn(str,level=10)
		self.pfile "#{str}\n",'stdtolog' if Thread.current['stdtolog']
		return if level > $dbglevel
		if $colored 
			print "\e[35;1m[*] #{str}\e[0m\n"
		else
			print "[*] #{str}\n"
		end
	end

	# black on white
	def self.praw(str,level=20)
		self.pfile "#{str}\n",'stdtolog' if Thread.current['stdtolog']
		return if level > $dbglevel
		p str
	end

	# pexcept
	def self.pexcept(e,mark='')
		if e.instance_of?(String)
			self.pdbg(e,0)
		else 
			self.pdbg("[#{mark}]:#{e.exception}",0)
			e.backtrace.each do |x| 
				self.pdbg("[#{mark}]:#{x}",0)
			end
		end
	end

	# file exception
	def self.fexcept(e,mark='')
		self.pexcept(e,mark)
		if e.instance_of?(String)
			$fexception.write(e)
		else
			self.pfile("------------------------\n","exceptions.log")
			self.pfile("[#{mark}]:#{e.exception}\n","exceptions.log")
			e.backtrace.each do |x|
				self.pfile("[#{mark}]:#{x}\n","exceptions.log")
			end
		end
	end
end

Debug.setRedirectToLogging(false)

# pfile
def pfile(str,file="default.log")
	Debug.pfile(str,file)
end
# red
def pdbg(str,level=10)
	Debug.pdbg(str,level)
end
# green
def pinfo(str,level=10)
	Debug.pinfo(str,level)
end
# purpule 
def pwarn(str,level=10)
	Debug.pwarn(str,level)
end
# black on white
def praw(str,level=20)
	Debug.praw(str,level)
end
# pexcept
def pexcept(e,mark='')
	Debug.pexcept(e,mark)
end
# File exception
def fexcept(e,mark='')
	Debug.fexcept(e,mark)
end

