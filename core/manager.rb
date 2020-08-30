#!/usr/bin/ruby
require 'rubygems'
require_relative 'config.rb'
require_relative 'debug.rb'

# core
require_relative 'miniexpect.rb'
require_relative 'paramfilter.rb'
require_relative 'switch.rb'
# bdcom p3310
require_relative '../modules/bdcom_p3310.rb'
# snr 2960 24g
require_relative '../modules/snr_s2960_24g.rb'
# snr 2960 48g
require_relative '../modules/snr_s2960_48g.rb'
# snr 2965
require_relative '../modules/snr_s2965.rb'
# snr 2970
require_relative '../modules/snr_s2970g_48s.rb'
# snr 2990
require_relative '../modules/snr_s2990.rb'
# 2500
require_relative '../modules/qtech25.rb'
# 2802708300
#require_relative '../modules/qtech28template.rb'
require_relative '../modules/qtech28.rb'
require_relative '../modules/qtech27.rb'
require_relative '../modules/qtech83.rb'
# 2903900
#require_relative '../modules/qtech29template.rb'
require_relative '../modules/qtech29.rb'
require_relative '../modules/qtech39.rb'
# dlink
#require_relative '../modules/dgs1100template.rb'
require_relative '../modules/dgs1100rev_a.rb'
#require_relative '../modules/des3200template.rb'
require_relative '../modules/des3200rev_a.rb'
require_relative '../modules/des3200rev_c.rb'
require_relative '../modules/dgs3420.rb'
require_relative '../modules/des3526.rb'
# 8000s
require_relative '../modules/ali8000s.rb'
require_relative '../modules/ali8012m.rb'
# cisco
#require_relative '../modules/ciscotemplate.rb'
require_relative '../modules/cisco6506.rb'
require_relative '../modules/cisco3750.rb'
require_relative '../modules/cisco3550.rb'
require_relative '../modules/cisco2960.rb'
require_relative '../modules/cisco2950.rb'
require_relative '../modules/ciscocigesm.rb'
# ex4550
require_relative '../modules/junex4550.rb'
require_relative '../modules/junmx.rb'
require_relative '../modules/jun2320.rb'
# se100
require_relative '../modules/se100.rb'
# eltex
require_relative '../modules/eltexmes1124.rb'
require_relative '../modules/eltexmes2324fb.rb'
require_relative '../modules/templates/eltex_ltp4x_template.rb'
require_relative '../modules/templates/eltex_lte8x_template.rb'
require_relative '../modules/templates/mikrotik_template.rb'

class SwitchManager

	def initialize(m,port=23,&block)

		if port.instance_of? String
			port = port.to_i
		end

		if m.instance_of? Miniexpect
			@me = m
		elsif m.instance_of? String
			@me = Miniexpect.new(m,port,&block)
			@me.debug = false
			@me.raw = false
		end
		@sw = Switch.new(@me)
	end
	
	def getContainer()

		# login and passive version
		return nil if !@sw.login()
		# active version check 
		v = @sw.checkInteractiveVersion()
		#p "VERSION #{v}"

		if @sw.myclass != nil
			wrk = Object.const_get(@sw.myclass).new(@me)
		else
			pdbg "Version no recognized.",0
			@me.close()
			@me.checkClose?()	# for read wraped telnet exit status
			return nil
		end
		wrk.copy_all_public(@sw)
		wrk
	end
end
