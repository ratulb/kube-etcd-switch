#!/usr/bin/env bash
. utils.sh
prnt "Initializing..."

sudo apt update
. install-cfssl.sh
sudo apt install tree -y
sudo apt autoremove -y

sed -i "s/#ETCD_VER#/$etcd_version/g" install-etcd.script
sed -i "s|#kube_vault#|$kube_vault|g" archive.script 
sed -i "s|#kube_vault#|$kube_vault|g" unarchive.script 

sudo mkdir -p $kube_vault/migration-archive
sudo mkdir -p $default_backup_loc
sudo mkdir -p $gendir
sudo rm cs.sh
sudo ln -s ./checks/cluster-state.sh cs.sh

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

  if [ ! -f $kube_vault/etcd.yaml.encoded ] || [ ! -f $kube_vault/kube-apiserver.yaml.encoded ]; then
    sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
      UserKnownHostsFile=/dev/null \
      $master_ip:/etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault
    cat $kube_vault/etcd.yaml | base64 > $kube_vault/etcd.yaml.encoded
    rm $kube_vault/etcd.yaml
    cat $kube_vault/kube-apiserver.yaml | base64 > $kube_vault/kube-apiserver.yaml.encoded
    rm $kube_vault/kube-apiserver.yaml
  fi

  prnt "Setting up kubectl on $this_host_ip"
  . setup-kubectl.sh

  prnt "Installing etcd on $master_ip"
  . execute-script-remote.sh $master_ip install-etcd.script
else
  cat /etc/kubernetes/manifests/etcd.yaml | base64 > $kube_vault/etcd.yaml.encoded
  cat /etc/kubernetes/manifests/kube-apiserver.yaml | base64 > $kube_vault/kube-apiserver.yaml.encoded
fi

kubectl -n kube-system get pod && prnt "\nkubectl has been setup" || "Some problem occured!"
