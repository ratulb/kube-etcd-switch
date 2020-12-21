#!/usr/bin/env bash
. utils.sh
  if [ "$this_host_ip" = $master_ip ];
    then
      mv /etc/kubernetes/manifests/kube-apiserver.yaml $kube_vault/paused-kube-apiserver.yaml
   else
sudo -u $usr ssh $master_ip "mv /etc/kubernetes/manifests/kube-apiserver.yaml \
	$kube_vault/paused-kube-apiserver.yaml"
  fi
 
