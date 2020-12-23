#!/usr/bin/env bash
. utils.sh
if [ "$this_host_ip" = $master_ip ]; then
  mv /etc/kubernetes/manifests/etcd.yaml $kube_vault/etcd.yaml
else
  sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $master_ip:/etc/kubernetes/manifests/etcd.yaml $kube_vault/etcd.yaml

  if [ -f $kube_vault/paused-etcd.yaml ]; then
    sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $master_ip rm -f /etc/kubernetes/manifests/etcd.yaml
  fi

fi
