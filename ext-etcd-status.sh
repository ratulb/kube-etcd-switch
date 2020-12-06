#!/usr/bin/env bash
. utils.sh

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 if [ -z $host ] || [ -z $ip ];
   then
     err_msg "Host or IP address is not valid - can not proceed!"
     exit 1
 fi
 ping -c 2 $ip
 if [ $? = 0 ]; then
   . execute-file-remote.sh $ip etcd-status.cmd

 fi

 
done



