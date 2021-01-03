#!/usr/bin/env bash
. utils.sh

stop_only_master=$1
stopping_for_admitted_node=$2
servers=$etcd_ips
if [ ! -z "$stopping_for_admitted_node" ]; then
  servers=$stopping_for_admitted_node
fi

prnt "Stopping etcd on servers : $servers"
for ip in $servers; do
  #Revisit this - for we might need to remove the master from the etcd cluster"
  if [[ ! -z "$stop_only_master" ]] && [[ "$ip" != "$master_ip" ]]; then
    debug "Not stopping @host($ip) - because not master($master_ip)"
    continue
  fi
  if [ "$ip" = "$this_host_ip" ]; then
    . stop-etcd.script
  else
    . execute-script-remote.sh $ip stop-etcd.script
  fi
done
prnt "Etcd cluster stopped."
