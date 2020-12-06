#!/usr/bin/env bash
. utils.sh

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 . execute-file-remote.sh $ip uninstall-etcd.sh
 
done



