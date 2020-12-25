#!/usr/bin/env bash
. utils.sh

prnt "Starting etcd on servers : $etcd_ips"
for ip in $etcd_ips; do
  if [ "$this_host_ip" = $ip ]; then
    . start-etcd.script
  else
    . execute-script-remote.sh $ip start-etcd.script
  fi
done
prnt "Etcd cluster started."
