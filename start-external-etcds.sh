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
servers_with_access_issues=''
servers_with_etcd_start_issues=''
prnt "Starting etcd on server(s) : $servers"
for ip in $servers; do
  if can_access_ip $ip; then
    if [ "$this_host_ip" = $ip ]; then
      . start-etcd.script
    else
      remote_script $ip start-etcd.script
    fi
    if [ "$?" -ne 0 ]; then
      servers_with_etcd_start_issues+="$ip "
      err "Error while starting etcd node($ip) - etcd start returned failed response"
    fi
  else
    err "Can not access host($ip) - etcd server not started on!"
    servers_with_access_issues+="$ip "
  fi
done
servers_with_access_issues=$(echo $servers_with_access_issues | xargs)
servers_with_etcd_start_issues=$(echo $servers_with_etcd_start_issues | xargs)
if [[ -z "$servers_with_access_issues" ]] && [[ -z $servers_with_etcd_start_issues ]]; then
  prnt "Etcd cluster($servers) started."
else
  if [ ! -z "$servers_with_access_issues" ]; then
    err "Start etcd server failed at servers($servers_with_access_issues) due to access issues."
  fi
  if [ ! -z "$servers_with_etcd_start_issues" ]; then
    err "Start etcd server failed at servers($servers_with_etcd_start_issues) due to missing configurations which have not been copied or it may not have joined the cluster yet."
  fi
fi
