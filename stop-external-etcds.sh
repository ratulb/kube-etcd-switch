#!/usr/bin/env bash
. utils.sh

prnt "Stopping etcd on servers : $etcd_ips"
for ip in $etcd_ips; do
  if [ "$ip" = "$this_host_ip" ]; then
    . stop-etcd.script
  else
    . execute-script-remote.sh $ip stop-etcd.script
  fi
done
prnt "Etcd cluster stopped."
