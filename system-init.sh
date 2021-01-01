#!/usr/bin/env bash
. utils.sh
prnt "kube-etcd-switch initializing..."

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
#check ssh acces before we proceed any furthers
. checks/ssh-access.sh
if [ ! "$this_host_ip" = "$master_ip" ]; then
  prnt "Copying etcd certs to $this_host_ip"
  sudo mkdir -p /etc/kubernetes/pki/etcd/

sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/pki/{apiserver-etcd-client.crt,apiserver-etcd-client.key} /etc/kubernetes/pki/ || ( err "Could not copy client cert and keys from $master_ip. System initialization is not complete!" && exit 1 )

sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/pki/etcd/{ca.crt,ca.key} /etc/kubernetes/pki/etcd/ || ( err "Could not copy ca credenentials from $master_ip. System initialization is not complete!" && exit 1 )
    sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} $kube_vault

    if [ -s $kube_vault/etcd.yaml ]; then
      cat /etc/kubernetes/manifests/etcd.yaml | base64 >"$kube_vault"/etcd.yaml.encoded
      rm $kube_vault/etcd.yaml
    else
      echo -e "\e[31metcd.yaml is empty or does not exist! System initialization not complete.\e[0m"
      exit 1
    fi
    if [ -s $kube_vault/kube-apiserver.yaml ]; then
      cat /etc/kubernetes/manifests/kube-apiserver.yaml | base64 >"$kube_vault"/kube-apiserver.yaml.encoded
      rm $kube_vault/kube-apiserver.yaml
    else
      echo -e "\e[31mkube-apiserver.yaml is empty or does not exist! System initialization not complete.\e[0m"
      exit 1
    fi

  prnt "Setting up kubectl on $this_host_ip"
  . setup-kubectl.sh

  prnt "Installing etcd on $master_ip"
  . execute-script-remote.sh $master_ip install-etcd.script
else
  if [ -s /etc/kubernetes/manifests/etcd.yaml ]; then
    cat /etc/kubernetes/manifests/etcd.yaml | base64 >"$kube_vault"/etcd.yaml.encoded
  else
    echo -e "\e[31metcd.yaml is empty or does not exist! System initialization is not complete!\e[0m"
    exit 1
  fi
  if [ -s /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
    cat /etc/kubernetes/manifests/kube-apiserver.yaml | base64 >"$kube_vault"/kube-apiserver.yaml.encoded
  else
    echo -e "\e[31mkube-apiserver.yaml is empty or does not exist! System initialization is not complete!\e[0m"
    exit 1
  fi
fi

kubectl -n kube-system get pod && prnt "\nkubectl has been setup" || "Some problem occured!"
