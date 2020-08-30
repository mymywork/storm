#!/bin/sh
#
ruby app/taskchange.rb -t map -p 0 -d "Discover hosts and services reachable."
# WARRING subnets must be increasing sequence.
SUBNETS='192.168.1.0/24'
echo "Subnets $SUBNETS"
# reachable
echo "[*] Discover hosts and services reachable."
nmap -n -sS -PE -p 22,23  $SUBNETS -oX discovered.xml
# injecting host in db
ruby app/nmap_xmlparser.rb -f ./discovered.xml
#
ruby app/taskchange.rb -t map -p 50 -d "Arp resolving hosts."
#
echo "[*] Resolving arp records."
# 
# arp resolving
ruby app/arpresolver.rb 192.168.1.1 22
ruby app/taskchange.rb -t map -p 100 -d "Discovering successfully"
