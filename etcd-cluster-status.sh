#!/usr/bin/env bash
. utils.sh

for ip in $etcd_ips; do
 if [ "$ip" = "$this_host_ip" ];
   then
     . etcd-status.script
   else
     ping -c 1 $ip
     if [ $? = 0 ]; then
     remote_script $ip etcd-status.script
     fi
 fi
done


