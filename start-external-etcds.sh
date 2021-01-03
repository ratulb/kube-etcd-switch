#!/usr/bin/env bash
. utils.sh

servers=$@
if [ -z "$servers" ]; then
  servers=$etcd_ips
fi
if [ -z "$servers" ]; then
  err "Empty etcd server ips. Not proceeding with etcd server start!"
  return 1
fi
prnt "Starting etcd on server(s) : $servers"
for ip in $servers; do
  if can_access_ip $ip; then
    if [ "$this_host_ip" = $ip ]; then
      . start-etcd.script
    else
      . execute-script-remote.sh $ip start-etcd.script
    fi
  else
    err "Can not access host($ip) - etcd server not started on!"
  fi
done
prnt "Etcd cluster started."
