#!/usr/bin/env bash
. utils.sh
#Observer how this behave
kubectl -n kube-system delete pod etcd-$master_name > /dev/null 2>&1 &

if [ "$this_host_ip" = $master_ip ]; then
  if [ -f /etc/kubernetes/manifests/etcd.yaml ]; then
    sudo rm /etc/kubernetes/manifests/etcd.yaml
  else
    err "Stopping etcd - no etcd.yaml @$this_host_ip"
  fi
else
  . execute-command-remote.sh $master_ip ls /etc/kubernetes/manifests/etcd.yaml
  if [ "$?" -eq 0 ]; then
    . execute-command-remote.sh $master_ip rm /etc/kubernetes/manifests/etcd.yaml
  else
    err "Stopping etcd - no etcd.yaml @$master_ip"
  fi
fi
