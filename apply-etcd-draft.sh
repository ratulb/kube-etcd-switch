#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 kube-apiserver's IP" >&2
  exit 1
fi
if [ "$this_host_ip" = $1 ]; then
  cp etcd.draft /etc/kubernetes/manifests/etcd.yaml
else
  sudo -u $usr scp etcd.draft $1:/etc/kubernetes/manifests/etcd.yaml
fi
