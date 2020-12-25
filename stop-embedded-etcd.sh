#!/usr/bin/env bash
. utils.sh
if [ "$this_host_ip" = $master_ip ]; then
  sudo rm /etc/kubernetes/manifests/etcd.yaml
else
  sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $master_ip rm -f /etc/kubernetes/manifests/etcd.yaml
fi
