#!/usr/bin/env bash
. utils.sh
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 kube-apiserver's IP" >&2
    exit 1
  fi
  if [ "$this_host_ip" = $1 ];
    then
      mv /etc/kubernetes/manifests/etcd.yaml $kube_vault/paused-etcd.yaml
   else
sudo -u $usr ssh $1 "mv /etc/kubernetes/manifests/etcd.yaml \
	$kube_vault/paused-etcd.yaml"
  fi
 
