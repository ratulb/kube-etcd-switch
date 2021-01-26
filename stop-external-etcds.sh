#!/usr/bin/env bash
. utils.sh

servers=$etcd_ips
if [ "$#" -gt 0 ]; then
  servers=$@
fi
servers_stopped_at=''
servers_not_stopped_at=''

prnt "Stopping etcd on servers : $servers"
for ip in $servers; do
  if can_access_address $ip; then
    if [ "$ip" = "$this_host_ip" ]; then
      . stop-etcd.script
    else
      remote_script $ip stop-etcd.script
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

prnt "Etcd server stop request was processed"
