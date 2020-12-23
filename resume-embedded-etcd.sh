#!/usr/bin/env bash
. utils.sh

if [ -f $kube_vault/etcd.yaml ]; then

  if [ "$this_host_ip" = $master_ip ]; then
    cp $kube_vault/etcd.yaml /etc/kubernetes/manifests/etcd.yaml
  else
    sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      $kube_vault/etcd.yaml $master_ip:/etc/kubernetes/manifests/etcd.yaml
  fi

else
  err "etcd.yaml not found to restore!"
fi
