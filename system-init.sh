#!/usr/bin/env bash
. utils.sh
prnt "Initializing..."
sudo apt update
. install-cfssl.sh
sudo apt install tree -y
sudo apt autoremove -y
mkdir -p $kube_vault
this_host_ip=$(hostname -i)
if [ ! "$this_host_ip" = $master_ip ]; then
. prepare-etcd-dirs.script $default_backup_loc
. steal-master-secrets.sh $master_ip
sudo -u $usr ssh $master_ip "mkdir -p $kube_vault && echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt && cp /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault"
sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip "mkdir -p $kube_vault && echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt && cp /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault"
./init-self.sh
. execute-script-remote.sh $master_ip install-etcd.script 
else
   echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt
   cp /etc/kubernetes/manifests/etcd.yaml $kube_vault/etcd.yaml
   cp /etc/kubernetes/manifests/kube-apiserver.yaml $kube_vault/kube-apiserver.yaml
fi
#house keeping stuff that would be needed
sed -i "s/#ETCD_VER#/$etcd_version/g" install-etcd.script
mkdir -p $default_backup_loc
install_etcdctl
