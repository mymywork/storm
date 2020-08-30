#!/bin/sh
#service tmuxstorm stop
if [ "$1" = "new" ]; then
	echo "[*] Backuping database"
	rm db/database.db.20*
	mv db/database.db db/database.db.`date +%F_%H%M%S`
	echo "[*] Backuping log"
	rm -rf log.20*
	mv log log.`date +%F_%H%M%S`
	mkdir log
	mkdir log/pids
fi
ruby app/taskchange.rb -t map -r 
./zmake_hostdiscovery.sh
if [ $? -gt 0 ]; then
	exit
fi
#exit
./macrefresh.sh & echo $! > ./macrefresh.pid
./zmake_map.sh
kill `cat ./macrefresh.pid`
rm -f ./macrefresh.pid
./zmake_info.sh
ruby app/taskchange.rb -g map -t "Generating map" -p 0 -d "Exporting geo data from zabbix"
ruby app/geo_import_zabbix.rb
ruby app/taskchange.rb -g map -t "Generating map" -p 50 -d "Making tree links and html template"
ruby app/htmlgen.rb -f -b 
ruby app/taskchange.rb -t map -s -p 100 -d "Map generated successfully at `date -R`"
#service tmuxstorm start
