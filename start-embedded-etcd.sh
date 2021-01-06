#!/usr/bin/env bash
. utils.sh
if [ -s $kube_vault/etcd.yaml ]; then
  if [ "$this_host_ip" = $master_ip ]; then
    cp $kube_vault/etcd.yaml /etc/kubernetes/manifests/
  else
    sudo -u $usr scp $kube_vault/etcd.yaml $master_ip:/etc/kubernetes/manifests/
  fi
else
  err "Error starting embedded etcd - no good etcd.yaml at kube vault"
fi
