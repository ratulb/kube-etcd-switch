#!/usr/bin/env bash
#Generates the certicates for etcd servers. Configurable options are ETCD_SNAPSHOT, IP_ADDRESS(endpints where to connect for creating the snapshot and name of the certificate file to use(Uses certicate by the name of the hostname by default but can be overridden.


. utils.sh

if [ ! -d /etc/kubernetes/pki/etcd ]; then
  err "Not found: /etc/kubernetes/pki/etcd"
  exit 1
fi
status=$(kubectl -n kube-system get pod | grep etcd | awk '{print $3}')
if [ ! "$status" = "Running" ];
  then
    err "etcd pod does not seem to be up"
fi

install_etcdctl

IP_ADDRESS=${IP_ADDRESS:-$(hostname -i)}

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --endpoints=$IP_ADDRESS:2379 member list

if [ ! $? = 0 ]; then
  err "etcd endpoint list failed - can not restore!"
  exit 1
fi

count=0
if [ -d "$default_backup_loc" ];
  then
    count=$(find $default_backup_loc -maxdepth 1 -type f -name "*.db" | wc -l)
  else 
    mkdir -p $default_backup_loc
fi
((count++))


ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$default_backup_loc/snapshot#$count.db}
SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
mkdir -p $SNAPSHOT_DIR
if [ -z $prompt ]; then
  prnt "Would store the snapshot to $ETCD_SNAPSHOT. Can change the location by setting the ETCD_SNAPSHOT environment varibale."
fi

read -p "Proceed with the backup? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err "\nAborted backup.\n"
    exit 1
fi
install_etcdctl

ETCD_CERT=${ETCD_CERT:-"server"}

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/${ETCD_CERT}.crt --key=/etc/kubernetes/pki/etcd/${ETCD_CERT}.key --endpoints=$IP_ADDRESS:2379 snapshot save $ETCD_SNAPSHOT

encoded=$(basename -- "$ETCD_SNAPSHOT")
encoded="${encoded%.*}"
cat /etc/kubernetes/manifests/etcd.yaml | base64 >  $SNAPSHOT_DIR/$encoded.nodelete

prnt "etcd snapshot saved at $ETCD_SNAPSHOT and status is:"
etcdctl snapshot status $ETCD_SNAPSHOT --write-out=table

