require 'erb'

class ERBContext
	def initialize(hash)
		hash.each do |k,v|
			self.instance_variable_set("@#{k}",v)
		end
	end

	def renderWithLayout(layout,page)
		self.instance_variable_set("@page",page)
		content = File.read(File.expand_path(layout))
		t = ERB.new(content)
		r = t.result(binding)
		#p r
		r
	end

	def render(path)
		content = File.read(File.expand_path(path))
		t = ERB.new(content)
		r = t.result(binding)
		#p r
		r
	end
end
