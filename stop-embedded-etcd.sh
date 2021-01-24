#!/usr/bin/env bash
. utils.sh
#Observe how this behaves
kubectl -n kube-system delete pod etcd-$master_name >/dev/null 2>&1 &

if [ "$this_host_ip" = $master_ip ]; then
  if [ -f /etc/kubernetes/manifests/etcd.yaml ]; then
    sudo mv /etc/kubernetes/manifests/etcd.yaml $kube_vault/
  else
    err "Stopping etcd - no etcd.yaml @$this_host_ip"
  fi
else
  remote_cmd $master_ip ls /etc/kubernetes/manifests/etcd.yaml
  if [ "$?" -eq 0 ]; then
    sudo -u $usr scp $master_ip:/etc/kubernetes/manifests/etcd.yaml $kube_vault/
    remote_cmd $master_ip rm /etc/kubernetes/manifests/etcd.yaml
  else
    err "Stopping etcd - no etcd.yaml @$master_ip"
  fi
fi
