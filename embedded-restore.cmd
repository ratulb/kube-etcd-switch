#!/usr/bin/env bash 
. utils.sh

ETCD_SNAPSHOT=#ETCD_SNAPSHOT#
RESTORE_PATH=#RESTORE_PATH#
TOKEN=#TOKEN#

ETCDCTL_API=3 etcdctl snapshot restore $ETCD_SNAPSHOT \
  --name=$(hostname) \
  --data-dir=$RESTORE_PATH \
  --initial-advertise-peer-urls=https://$(hostname -i):2380 \
  --initial-cluster $(hostname)=https://$(hostname -i):2380 \
  --initial-cluster-token=${TOKEN} \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  --endpoints=https://$(hostname -i):2379


