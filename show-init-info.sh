#!/usr/bin/env bash

. utils.sh

prnt "Showing system information"

prnt "This machine's($(hostname -i)) info"

prnt "kube vault($kube_vault) contents : "
ls -la $kube_vault

prnt "/etc/kubernetes/pki : "

ls -la /etc/kubernetes/pki

prnt "/etc/kubernetets/pki/etcd : "

ls -la /etc/kubernetes/pki/etcd

if [ "$master_ip" = $(hostname -i) ]; then
  prnt "This machine is the master"
  return 0
fi

prnt "This machine is not master - showing master information"

prnt "$kube_vault data "

sudo -u $usr ssh $master_ip "ls -la $kube_vault"

prnt "$/etc/kubernetes/pki"

sudo -u $usr ssh $master_ip "ls -la /etc/kubernetes/pki"

prnt "$/etc/kubernetes/pki/etcd"

sudo -u $usr ssh $master_ip "ls -la /etc/kubernetes/pki/etcd"
