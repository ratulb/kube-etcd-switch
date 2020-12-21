#!/usr/bin/env bash
. utils.sh
  if [ "$this_host_ip" = "$master_ip" ];
    then
      mv /etc/kubernetes/manifests/etcd.yaml $kube_vault/paused-etcd.yaml
   else
sudo -u $usr ssh $master_ip "mv /etc/kubernetes/manifests/etcd.yaml \
	$kube_vault/paused-etcd.yaml"
  fi
 
