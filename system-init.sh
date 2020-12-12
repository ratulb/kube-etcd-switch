#!/usr/bin/env bash
. utils.sh
prnt "Initializing..."
mkdir -p $kube_vault
this_host_ip=$(hostname -i)
if [ ! "$this_host_ip" = $master_ip ]; then
. make-dirs.script
. steal-master-secrets.sh $master_ip
sudo -u $usr ssh $master_ip "mkdir -p $kube_vault && echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt && cp /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault"
. execute-script-remote.sh $master_ip install-etcd.script 
else
   echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt
   cp /etc/kubernetes/manifests/etcd.yaml $kube_vault/etcd.yaml
   cp /etc/kubernetes/manifests/kube-apiserver.yaml $kube_vault/kube-apiserver.yaml
fi
install_etcdctl
