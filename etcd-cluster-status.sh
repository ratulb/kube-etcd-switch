#!/usr/bin/env bash
. utils.sh

this_ip=$(hostname -i)
up_etcds=''
for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 if [ -z $host ] || [ -z $ip ];
   then
     err "Host or IP address is not valid - can not proceed!"
     exit 1
 fi
 if [ "$ip" = "$this_ip" ];
   then
     . etcd-status.script
   else
     ping -c 1 $ip
     if [ $? = 0 ]; then
     . execute-script-remote.sh $ip etcd-status.script
     fi
 fi
done


