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
sudo rm ep.sh
sudo ln -s checks/cluster-state.sh cs.sh
sudo ln -s checks/endpoint-liveness-cluster.sh ep.sh

prnt "Installing etcd on $this_host_ip"
. install-etcd.script
#check ssh acces before we proceed any furthers
if ! can_access_ip $master_ip; then
  err "Can not access kubernetes master@$master_ip - Not proceeding with system initialization"
  return 1
fi

if [ ! "$this_host_ip" = "$master_ip" ]; then
  prnt "Copying etcd certs to $this_host_ip"
  sudo mkdir -p /etc/kubernetes/pki/etcd/

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/pki/apiserver-etcd-client.crt /etc/kubernetes/pki/

  if [ "$?" -ne 0 ]; then
    err "Could not copy client cert from $master_ip. System initialization is not complete!"
    return 1
  fi

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/pki/apiserver-etcd-client.key /etc/kubernetes/pki/

  if [ "$?" -ne 0 ]; then
    err "Could not copy client key from $master_ip. System initialization is not complete!"
    return 1
  fi

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/

  if [ "$?" -ne 0 ]; then
    err "Could not copy ca.crt from $master_ip. System initialization is not complete!"
    return 1
  fi

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/pki/etcd/ca.key /etc/kubernetes/pki/etcd/

  if [ "$?" -ne 0 ]; then
    err "Could not copy ca.key from $master_ip. System initialization is not complete!"
    return 1
  fi

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/manifests/etcd.yaml $kube_vault

  if [ "$?" -ne 0 ]; then
    err "Could not copy etcd.yaml $master_ip. System initialization is not complete!"
    return 1
  fi

  if [ -s $kube_vault/etcd.yaml ]; then
    cat $kube_vault/etcd.yaml | base64 >"$kube_vault"/etcd.yaml.encoded
    rm $kube_vault/etcd.yaml
  else
    echo -e "\e[31metcd.yaml is empty or does not exist! System initialization not complete.\e[0m"
    return 1
  fi

  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml $kube_vault

  if [ "$?" -ne 0 ]; then
    err "Could not copy kube-apiserver.yaml from $master_ip. System initialization is not complete!"
    return 1
  fi

  if [ -s $kube_vault/kube-apiserver.yaml ]; then
    cat $kube_vault/kube-apiserver.yaml | base64 >"$kube_vault"/kube-apiserver.yaml.encoded
    rm $kube_vault/kube-apiserver.yaml
  else
    echo -e "\e[31mkube-apiserver.yaml is empty or does not exist! System initialization not complete.\e[0m"
    return 1
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
    return 1
  fi
  if [ -s /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
    cat /etc/kubernetes/manifests/kube-apiserver.yaml | base64 >"$kube_vault"/kube-apiserver.yaml.encoded
  else
    echo -e "\e[31mkube-apiserver.yaml is empty or does not exist! System initialization is not complete!\e[0m"
    return 1
  fi
fi
. gen-cert.sh $(hostname) $this_host_ip
cp $gendir/$(hostname){-peer.*,-client.*,-server.*} /etc/kubernetes/pki/etcd/ 

kubectl -n kube-system get pod && prnt "\nkubectl has been setup" || "Some problem occured!"
