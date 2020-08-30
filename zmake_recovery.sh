#!/bin/sh
#service tmuxstorm stop
./zmake_hostdiscovery.sh
if [ $? -gt 0 ]; then
	exit
fi
#exit
ruby app/htmlgen.rb -f -b 
./zmake_map.sh update
ruby app/getinfo.rb -u -m 23
#ruby app/taskchange.rb -g map -t "Generating map" -p 0 -d "Exporting geo data from zabbix"
#ruby app/geo_import_zabbix.rb
#ruby app/taskchange.rb -g map -t "Generating map" -p 50 -d "Making tree links and html template"
ruby app/htmlgen.rb -f -b 
#service tmuxstorm start
