#!/usr/bin/env bash
#Generates the certicates for etcd servers
. utils.sh
  
install_etcdctl

SNAPSHOT_PATH=${SNAPSHOT_PATH:-/var/lib/etcd-snapshot.db}
IP_ADDRESS=${IP_ADDRESS:-"127.0.0.1"}
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints=$IP_ADDRESS:2379 snapshot save $SNAPSHOT_PATH

#ETCDCTL_API=3 etcdctl snapshot save --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints=127.0.0.1:2379 $SNAPSHOT_PATH
prnt_msg "etcd snapshot saved at $SNAPSHOT_PATH and status is:"
etcdctl snapshot status $SNAPSHOT_PATH --write-out=table

