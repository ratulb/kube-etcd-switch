#!/usr/bin/env bash
#Generates the certicates for etcd servers. Configurable options are ETCD_SNAPSHOT, IP_ADDRESS(endpints where to connect for creating the snapshot and name of the certificate file to use(Uses certicate by the name of the hostname by default but can be overridden.


. utils.sh

if [ ! -d /etc/kubernetes/pki/etcd ]; then
  err "Not found: /etc/kubernetes/pki/etcd"
  exit 1
fi

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-/var/lib/etcd-snapshot.db}
SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
if [ -z $prompt ]; then
  prnt "Would store the snapshot to $ETCD_SNAPSHOT - ok? Can change the location by setting the ETCD_SNAPSHOT environment varibale. Do not modify contents underneath $SNAPSHOT_DIR"
fi

read -p "Proceed with the backup? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err "\nAborted backup.\n"
    exit 1
fi
install_etcdctl

mkdir -p $SNAPSHOT_DIR

IP_ADDRESS=${IP_ADDRESS:-$(hostname -i)}
ETCD_CERT=${ETCD_CERT:-"server"}

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/${ETCD_CERT}.crt --key=/etc/kubernetes/pki/etcd/${ETCD_CERT}.key --endpoints=$IP_ADDRESS:2379 snapshot save $ETCD_SNAPSHOT

encoded=$(basename -- "$ETCD_SNAPSHOT")
encoded="${encoded%.*}"
cat /etc/kubernetes/manifests/etcd.yaml | base64 >  $SNAPSHOT_DIR/$encoded.nodelete

prnt "etcd snapshot saved at $ETCD_SNAPSHOT and status is:"
etcdctl snapshot status $ETCD_SNAPSHOT --write-out=table

