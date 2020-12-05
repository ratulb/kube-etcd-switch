#!/usr/bin/env bash
#Generates the certicates for etcd servers. Configurable options are SNAPSHOT_PATH, IP_ADDRESS(endpints where to connect for creating the snapshot and name of the certificate file to use(Uses certicate by the name of the hostname by default but can be overridden.


. utils.sh

if [ ! -d /etc/kubernetes/pki/etcd ]; then
  err_msg "Not found: /etc/kubernetes/pki/etcd"
  exit 1
fi

install_etcdctl

SNAPSHOT_PATH=${SNAPSHOT_PATH:-/var/lib/etcd-snapshot.db}
SNAPSHOT_DIR=${SNAPSHOT_PATH%/*}
mkdir -p $SNAPSHOT_DIR

IP_ADDRESS=${IP_ADDRESS:-$(hostname -i)}
ETCD_CERT=${ETCD_CERT:-"server"}

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/${ETCD_CERT}.crt --key=/etc/kubernetes/pki/etcd/${ETCD_CERT}.key --endpoints=$IP_ADDRESS:2379 snapshot save $SNAPSHOT_PATH

prnt_msg "etcd snapshot saved at $SNAPSHOT_PATH and status is:"
etcdctl snapshot status $SNAPSHOT_PATH --write-out=table

