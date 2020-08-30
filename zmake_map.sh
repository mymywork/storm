#!/bin/sh

if [ "$1" = "update" ]; then
	echo "Recollection macs for update host."
	ruby app/collector.rb -m 20 -u --vlan 100
else
	echo "Map collecting."
	ruby app/collector.rb -c -m 20 --vlan 100
fi
