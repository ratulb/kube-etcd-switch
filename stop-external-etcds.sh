#!/usr/bin/env bash
. utils.sh

stop_only_master=$1
stopping_for_admitted_node=$2
servers=$etcd_ips
if [ ! -z "$stopping_for_admitted_node" ]; then
  servers=$stopping_for_admitted_node
fi
servers_stopped_at=''
servers_not_stopped_at=''
prnt "Stopping etcd on servers : $servers"
for ip in $servers; do
  if can_access_ip $ip; then
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
    servers_stopped_at+="$ip "
  else
    err "Failed to stop server at $ip - server is not accessible"
    servers_not_stopped_at+="$ip "
  fi
done
servers_stopped_at=$(echo $servers_stopped_at | xargs)
servers_not_stopped_at=$(echo $servers_not_stopped_at | xargs)
if [ ! -z "$servers_stopped_at" ]; then
  prnt "Server(s) stopped at $servers_stopped_at"
fi

if [ ! -z "$servers_not_stopped_at" ]; then
  prnt "Server(s) not stopped at $servers_not_stopped_at"
fi

prnt "Etcd server stop request was proccessed"
