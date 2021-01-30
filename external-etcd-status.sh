#!/usr/bin/env bash
. utils.sh

prnt "Checking etcd status on servers : $etcd_ips"
for ip in $etcd_ips; do
  if [ "$ip" = "$this_host_ip" ]; then
    sudo systemctl status etcd --no-pager
  else
    remote_cmd $ip sudo systemctl status etcd --no-pager
  fi
done
