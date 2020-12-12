#!/usr/bin/env bash
. utils.sh
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 kube-apiserver's IP" >&2
    exit 1
  fi
  this_host_ip=$(hostname -i)
  if [ "$1" = $this_host_ip ];
    then
      cp etcd.draft /etc/kubernetes/manifests/etcd.yaml
   else
sudo -u $usr scp etcd.draft $1:/etc/kubernetes/manifests/etcd.yaml 
  fi
 
