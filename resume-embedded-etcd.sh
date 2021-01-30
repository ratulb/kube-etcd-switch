#!/usr/bin/env bash
. utils.sh
master_ip=$1
if [ "$this_host_ip" = "$master_ip" ]; then
  if [ -s $kube_vault/etcd.yaml ]; then
    mv $kube_vault/etcd.yaml /etc/kubernetes/manifests/
    prnt "Resumed etcd at $master_ip"
  else
    if [ -s /etc/kubernetes/manifests/etcd.yaml ]; then
      prnt "Etcd is already configured for running"
    else
      err "Unknown error - etcd configuration is missing at $master_ip"
    fi
  fi
else
  remote_cmd $master_ip ls -la $kube_vault/etcd.yaml &>/dev/null
  if [ "$?" -eq 0 ]; then
    remote_cmd $master_ip mv $kube_vault/etcd.yaml /etc/kubernetes/manifests/ 
    prnt "Resumed etcd at $master_ip"
  else
    if ! is_etcd_suspended_at $master_ip; then
      prnt "Etcd is already configured for running"
    else
      err "Unknown error - etcd configuration is missing at $master_ip"
    fi
  fi
fi
