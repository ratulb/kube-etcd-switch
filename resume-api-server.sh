#!/usr/bin/env bash
. utils.sh
  if [ "$this_host_ip" = $master_ip ];
    then
      mv $kube_vault/paused-kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
   else
sudo -u $usr ssh $master_ip "mv $kube_vault/paused-kube-apiserver.yaml \
	/etc/kubernetes/manifests/kube-apiserver.yaml"
  fi
 
