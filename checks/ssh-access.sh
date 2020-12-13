#!/usr/bin/env bash
. utils.sh

this_host_ip=$(hostname -i)
this_host_ip=$(echo $this_host_ip | cut -d ' ' -f 1)
prnt "Make sure SSH public key has been copied to remote servers!"
for ip in $etcd_ips; do
  prnt "Checking accessibility on $ip"
  if [ "$this_host_ip" = $ip ]; then
    continue
  fi

  sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout 2" $ip ls -la &>/dev/null
  if [ ! "$?" = 0 ]; then
    err "Could not access $ip. Not proceeding!"
    exit 1
  fi
done
