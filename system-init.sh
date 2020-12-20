#!/usr/bin/env bash
. utils.sh
prnt "Initializing..."

sudo apt update
. install-cfssl.sh
sudo apt install tree -y
sudo apt autoremove -y

sed -i "s/#ETCD_VER#/$etcd_version/g" install-etcd.script
mkdir -p $kube_vault
mkdir -p $default_backup_loc
. install-etcd.script

if [ ! "$this_host_ip" = $master_ip ]; then
  
  sudo mkdir -p /etc/kubernetes/pki/etcd/

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
	UserKnownHostsFile=/dev/null \
        $1:/etc/kubernetes/pki/{apiserver-etcd-client.crt,apiserver-etcd-client.key} \
        /etc/kubernetes/pki/

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
        UserKnownHostsFile=/dev/null \
        $1:/etc/kubernetes/pki/etcd/{ca.crt,ca.key} \
        /etc/kubernetes/pki/etcd/

  sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	  $master_ip "mkdir -p $kube_vault && \
	  cp /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault"

  . setup-kubectl.sh
  . execute-script-remote.sh $master_ip install-etcd.script
else
  cp /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault
fi
