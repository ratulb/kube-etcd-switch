#!/usr/bin/env bash
. utils.sh
prnt "Initializing..."
mkdir -p $kube_vault
host_ip=$(hostname -i)
if [ ! "$host_ip" = $master_ip ]; then
. make-dirs.script
. steal-master-secrets.sh $master_ip
sudo -u $usr ssh $master_ip "mkdir -p $kube_vault && echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt"
 else
   echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt
   cp /etc/kubernetes/manifests/etcd.yaml $kube_vault/$(hostname -i)-etcd.yaml
fi
install_etcdctl
