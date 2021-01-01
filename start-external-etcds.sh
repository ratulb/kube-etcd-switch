#!/usr/bin/env bash
. utils.sh

if [ -z "$etcd_ips" ]; then
  err "Empty etcd server ips. Not proceeding with etcd server start!"
  return 1
fi
prnt "Starting etcd on servers : $etcd_ips"
for ip in $etcd_ips; do
  if [ "$this_host_ip" = $ip ]; then
    . start-etcd.script
  else
    . execute-script-remote.sh $ip start-etcd.script
  fi
done
prnt "Etcd cluster started."
