class Patterns

	#
	# _variables not a for copy in object switch
	#

	@@classes = [
		
		{
			"_myclass" => "DGS1100RevA",
			"version" => "dgs1100",
			"vendor" => "dlink"
		},
		{
			"_myclass" => "DES3200RevA",
			"version" => "des3200",
			"vendor" => "dlink",
			"revision" => "A1"
		},
		{
			"_myclass" => "DES3200RevA",
			"version" => "des3200",
			"vendor" => "dlink",
			"revision" => "B1"
		},
		{
			"_myclass" => "DES3200RevC",
			"version" => "des3200",
			"vendor" => "dlink",
			"revision" => "C1"
		},
		
		{
			"_myclass" => "DGS3420",
			"version" => "dgs3420",
			"vendor" => "dlink"
		},
		{
			"_myclass" => "DES3526",
			"version" => "des3526",
			"vendor" => "dlink"
		},
	
	]

	#
	# _variables not a for copy in object switch
	#

	@@space = [
		{
			"_banner" => true,
			"_pattern" => /VMWare/,
			"_next" => "skip",
			"version" => "vmware",
			"vendor" => "vmware"
		},
		{
			"_banner" => true,
			"_pattern" => /JUNOS/,
			"vendor" => "juniper"
		},
		{
			"_banner" => true,
			"_pattern" => /AT-8012M/,
			"_next" => "skip",
			"version" => "8012m"
		},
		{
			"_banner" => true,
			"_pattern" => /(TDMOP|TDMoP)/,
			"_next" => "skip",
			"version" => "tdmop"
		},
		{
			"_banner" => true,
			"_pattern" => /NPort/,
			"_next" => "skip",
			"version" => "nport",
		},
		{
			"_banner" => true,
			"_pattern" => /American Power Conversion/,
			"_next" => "skip",
			"version" => "symmetra",
		},
		{
			"_banner" => true,
			"_pattern" => /Nortel/,
			"_next" => "skip",
			"version" => "nortel",
		},
		{
			"_banner" => true,
			"_pattern" => /BDCOM P3310/,
			"_myclass" => "BdcomP3310",
			"version" => "p3310",
			"vendor" => "bdcom"
		},
		{
			"_banner" => true,
			"_pattern" => /BDCOM P3608-2TE/,
			"_myclass" => "BdcomP3310",
			"version" => "p3608-2te",
			"vendor" => "bdcom"
		},
		{
			"_banner" => true,
			"_pattern" => /SNR-S2970G-48S/,
			"_next" => "skip",
			"_myclass" => "SnrS2970G_48S",
			"version" => "s2970g_48s",
			"vendor" => "snr"
		},
		{
			"_banner" => true,
			"_pattern" => /System\(QOS\)/,
			"_next" => "skip",
			"_myclass" => "Qtech25",
			"version" => "2500",
			"vendor" => "qtech"
		},
		{
			"_banner" => true,
			"_pattern" => /DGS-1100-([0-9]+)/,
			"block" => Proc.new { |slf,x,e|
				slf.portsnum = x[1].to_i
				pinfo "Dlink with #{slf.portsnum} ports."
			},
			"_next" => ["dlink_revision","prompt","more"],
			"version" => "dgs1100",
			"vendor" => "dlink"
		},
		{
			"_banner" => true,
			"_pattern" => /DES-3526/,
			"portsnum" => 26,
			"version" => "des3526",
			"vendor" => "dlink"
		},
		{
			"_banner" => true,
			"_pattern" => /DGS-3420-([0-9]+)/,
			"block" => Proc.new { |slf,x,e|
				slf.portsnum = x[1].to_i
				pinfo "Dlink with #{slf.portsnum} ports."
			},
			"version" => "dgs3420",
			"vendor" => "dlink"
		},
		{
			"_banner" => true,
			"_pattern" => /DES-3200-([0-9]+)/,
			"block" => Proc.new { |slf,x,e|
				slf.portsnum = x[1].to_i
				pinfo "Dlink with #{slf.portsnum} ports."
			},
			"version" => "des3200",
			"vendor" => "dlink"
		},
		{
			"_banner" => true,
			"_pattern" => /Optical line terminal LTP-4X/,
			"_next" => "skip",
			"_myclass" => "EltexLtp4xTemplate",
			"version" => "ltp4x",
			"vendor" => "eltex"
		},
		{
			"_banner" => true,
			"_pattern" => /LTE-8X/,
			"_next" => "skip",
			"_myclass" => "EltexLte8xTemplate",
			"version" => "lte8x",
			"vendor" => "eltex"
		},
		{
			"_banner" => true,
			"_pattern" => /MikroTik/,
			"_next" => "skip",
			"_myclass" => "MikrotikTemplate",
			"version" => "mikrotik",
			"vendor" => "mikrotik"
		},


		#
		# blocks after authorization
		#
		
		{
			"_name" => "dlink_revision",
			"_pattern" => /Hardware Version[\s\t]+:[\s\t]+([a-zA-Z0-9]+)\n/,
			"_myclass" => @@classes,
			"block" => Proc.new { |slf,x,e|
				if slf.vendor == "dlink"
					pinfo "Revision: #{x[1]}"
					slf.revision = x[1]
				end
			},
			"notdefault" => true
		},
		{ 	
			"_name" => "prompt",
			"_pattern" => /#|>/,
			"block" => Proc.new { |slf,x,e|
				pinfo "Detected prompt"
				break
			}
		},
		{
			"_name" => "more",
			"_pattern" => /(more|More|SPACE)/,
			"block" => Proc.new { |slf,x,e|
				pinfo "More"
				if slf.vendor == "dlink"
					slf.send("a")
				else
					slf.send(" ")
				end
			}
		},

		#
		# patterns after interactive version check
		#


		{
			"_pattern" => /Model:\s+j2320/,
			"_myclass" => "Jun2320",
			"version" => "j2320",
			"vendor" => "juniper"
		},
		{
			"_pattern" => /Model:\s+m7i/,
			"_myclass" => "JunMX",
			"version" => "m7i",
			"vendor" => "juniper"
		},
		{
			"_pattern" => /Model:\s+mx80/,
			"_myclass" => "JunMX",
			"version" => "mx80",
			"vendor" => "juniper"
		},
		{
			"_pattern" => /Model:\s+ex4550/,
			"_myclass" => "JunEx4550",
			"version" => "ex4550",
			"vendor" => "juniper"
		},
		{
			"_pattern" => /(SNR-S2950|Switch Device, Compiled)/,
			"_myclass" => "SnrS2960_24G",
			"version" => "snr2950",
			"vendor" => "snr"
		},
		{
			"_pattern" => /SNR-S2960-24G/,
			"_myclass" => "SnrS2960_24G",
			"version" => "s2960_24g",
			"vendor" => "snr"
		},
		{
			"_pattern" => /SNR-S2960-48G/,
			"_myclass" => "SnrS2960_48G",
			"version" => "s2960_48g",
			"vendor" => "snr"
		},
		{
			"_pattern" => /SNR-S2965/,
			"_myclass" => "SnrS2965",
			"version" => "s2965",
			"vendor" => "snr"
		},
		{
			"_pattern" => /SNR-S2990G-24T/,
			"_myclass" => "SnrS2990",
			"version" => "s2990",
			"vendor" => "snr"
		},
		{
			"_pattern" => /QSW-2700/,
			"_myclass" => "Qtech27",
			"version" => "2700",
			"vendor" => "qtech"
		},
		{
			"_pattern" => /QSW-2800/,
			"_myclass" => "Qtech28",
			"version" => "2800",
			"vendor" => "qtech"
		},
		{
			"_pattern" => /QSW-2900/,
			"_myclass" => "Qtech29",
			"version" => "2900",
			"vendor" => "qtech"
		},
		{
			"_pattern" => /QSW-3900/,
			"_myclass" => "Qtech39",
			"version" => "3900",
			"vendor" => "qtech"
		},
		{
			"_pattern" => /QSW-8300/,
			"_myclass" => "Qtech83",
			"version" => "8300",
			"vendor" => "qtech"
		},
		{
			"_pattern" => /C6506/,
			"_myclass" => "Cisco6505",
			"version" => "c6506",
			"vendor" => "cisco"
		},
		{
			"_pattern" => /C2960/,
			"_myclass" => "Cisco2960",
			"version" => "c2960",
			"vendor" => "cisco"
		},
		{
			"_pattern" => /C2950/,
			"_myclass" => "Cisco2950",
			"version" => "c2950",
			"vendor" => "cisco"
		},
		{
			"_pattern" => /C3750/,
			"_myclass" => "Cisco3750",
			"version" => "c3750",
			"vendor" => "cisco"
		},
		{
			"_pattern" => /C3550/,
			"_myclass" => "Cisco3550",
			"version" => "c3550",
			"vendor" => "cisco"
		},
		{
			"_pattern" => /CIGESM/,
			"_myclass" => "CiscoCIGESM",
			"version" => "cigesm",
			"vendor" => "cisco"
		},
		{
			"_pattern" => /Active-image:/,
			"_myclass" => "EltexMES2324FB",
			"version" => "mes2324fb",
			"vendor" => "eltex"
		},
		{
			"_pattern" => /SW version\s+1/,
			"_myclass" => "EltexMES1124",
			"version" => "mes1124",
			"vendor" => "eltex"
		},
		{
			"_pattern" => /SW version\s+3/,
			"_myclass" => "Ali8000S",
			"version" => "ali8000s",
			"vendor" => "aliedtelesis"
		},
		{
			"_pattern" => /fdb/,
			"version" => "dlink",
			"vendor" => "dlink"
		},
		{
			"_pattern" => /Redback Networks SmartEdge/,
			"_myclass" => "SE100",
			"version" => "se100",
			"vendor" => "redback"
		}

	]


	@@actions = {
		# vendors interactive version get commands
		"dlink" => "sh switch\n",
		"juniper" => Proc.new { |slf|
			# specific Juniper   
			slf.send("cli\n")    
			slf.wait(">")            
			slf.send("sh ver\n");
		},
		"0" => "sh ver\n",
	}



	def self.space
		@@space
	end
	def self.actions
		@@actions
	end

end
