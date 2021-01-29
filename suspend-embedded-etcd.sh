#!/usr/bin/env bash
. utils.sh
master_name=$1
master_ip=$2
kubectl -n kube-system delete pod etcd-$master_name >/dev/null 2>&1 &

if [ "$this_host_ip" = $master_ip ]; then
  if [ -f /etc/kubernetes/manifests/etcd.yaml ]; then
    sudo mv /etc/kubernetes/manifests/etcd.yaml $kube_vault/
    prnt "Suspended etcd at $master_name($master_ip)"
  else
    err "Suspending etcd - no etcd.yaml @$this_host_ip"
  fi
else
  remote_cmd $master_ip ls -la /etc/kubernetes/manifests/etcd.yaml &>/dev/null
  if [ "$?" -eq 0 ]; then
    remote_cmd $master_ip mv /etc/kubernetes/manifests/etcd.yaml $kube_vault/
    prnt "Suspended etcd at $master_name($master_ip)"
  else
    err "Suspending etcd - no etcd.yaml at $master_ip"
  fi
fi
