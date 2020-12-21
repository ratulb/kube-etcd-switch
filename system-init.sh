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
mkdir -p $gendir

prnt "Installing etcd on $this_host_ip"
. install-etcd.script

if [ ! "$this_host_ip" = $master_ip ]; then

  prnt "Copying etcd certs to $this_host_ip"

  sudo mkdir -p /etc/kubernetes/pki/etcd/

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
    UserKnownHostsFile=/dev/null \
    $master_ip:/etc/kubernetes/pki/{apiserver-etcd-client.crt,apiserver-etcd-client.key} \
    /etc/kubernetes/pki/

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
    UserKnownHostsFile=/dev/null \
    $master_ip:/etc/kubernetes/pki/etcd/{ca.crt,ca.key} \
    /etc/kubernetes/pki/etcd/

  if [ ! -f $kube_vault/etcd.yaml ] || [ ! -f $kube_vault/kube-apiserver.yaml ]; then
    sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
      UserKnownHostsFile=/dev/null \
      $master_ip:/etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault
  fi

  sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip "mkdir -p $kube_vault"

  prnt "Setting up kubectl on $this_host_ip"
  . setup-kubectl.sh

  prnt "Installing etcd on $master_ip"
  . execute-script-remote.sh $master_ip install-etcd.script
else
  cp /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault
fi

kubectl -n kube-system get pod && prnt "\nkubectl has been setup" || "Some problem occured!"
