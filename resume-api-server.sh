#!/usr/bin/env bash
. utils.sh
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 kube-apiserver's IP" >&2
    exit 1
  fi
  this_host_ip=$(hostname -i)
  if [ "$1" = $this_host_ip ];
    then
      mv $kube_vault/paused-kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
   else
sudo -u $usr ssh $1 "mv $kube_vault/paused-kube-apiserver.yaml \
	/etc/kubernetes/manifests/kube-apiserver.yaml"
  fi
 
