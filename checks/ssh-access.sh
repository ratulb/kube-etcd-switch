#!/usr/bin/env bash
. utils.sh

#If master ip is not included in etcd_ips, add it to list of servers
server_ips=$etcd_ips
if [[ ! $etcd_ips =~ "$master_ip" ]]; then
  server_ips+=" $master_ip"
fi

prnt "Make sure SSH public key has been copied to remote servers!"
for ip in $server_ips; do
  prnt "Checking access to $ip"
  if [ "$this_host_ip" = $ip ]; then
    continue
  fi
  sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout 2" $ip ls -la &>/dev/null
  if [ ! "$?" = 0 ]; then
    err "Could not access $ip. Not proceeding!"
    exit 1
  fi
done
