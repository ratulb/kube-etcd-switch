#!/usr/bin/env bash
. utils.sh

prnt "Cleaning up local and remote setup on $etcd_ips"

prnt "Cleaning up on localhost($this_host_ip)"
rm -rf "$kube_vault"
rm -rf "$default_backup_loc"

. uninstall-node-etcd.sh


for ip in $etcd_ips; do
  if [ "$this_host_ip" = "$ip" ]; then
   prnt "Already cleaned on localhost"
   continue
  else
    sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $ip "rm -rf $kube_vault $default_backup_loc"
   sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $ip < uninstall-node-etcd.sh
  fi
  prnt "Cleaned up on $ip"
done

#If master is not part of etcd ips
if [[ ! $etcd_ips =~ "$master_ip" ]]; then

sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip "rm -rf $kube_vault $default
_backup_loc"
sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip < uninstall-node-etcd.sh
 prnt "Cleaned up on master($master_ip)"
fi

prnt "Cleaned up local and remote systems($this_host_ip,$master_ip,$etcd_ips)"
