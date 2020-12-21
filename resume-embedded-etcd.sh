#!/usr/bin/env bash
. utils.sh
  if [ "$this_host_ip" = "$master_ip" ];
    then
      mv $kube_vault/paused-etcd.yaml /etc/kubernetes/manifests/etcd.yaml
   else
sudo -u $usr ssh $master_ip "mv $kube_vault/paused-etcd.yaml \
	/etc/kubernetes/manifests/etcd.yaml"
  fi
 
