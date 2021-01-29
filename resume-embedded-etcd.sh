#!/usr/bin/env bash
. utils.sh
master_ip=$1
if [ "$this_host_ip" = "$master_ip" ]; then
  if [ -s $kube_vault/etcd.yaml ]; then
    mv $kube_vault/etcd.yaml /etc/kubernetes/manifests/
    prnt "Resumed etcd at $master_ip"
  else
    err "Error resuming embedded etcd - no good etcd.yaml at kube vault"
  fi
else
  remote_cmd $master_ip ls -la $kube_vault/etcd.yaml &>/dev/null
  if [ "$?" -eq 0 ]; then
    remote_cmd $master_ip $kube_vault/etcd.yaml /etc/kubernetes/manifests/
    prnt "Resumed etcd at $master_ip"
  else
    err "Error resuming embedded etcd - no good etcd.yaml at kube vault"
  fi
fi
