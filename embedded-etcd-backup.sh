#!/usr/bin/env bash

. utils.sh
. checks/ca-err.sh
. checks/etcd-pod-warn.sh
. checks/api-client-cert-err.sh
. checks/endpoint-err.sh

next_snapshot
ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$NEXT_SNAPSHOT}
SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
mkdir -p $SNAPSHOT_DIR

. checks/usr-ask.sh

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
	--cert=$kube_api_client_cert \
	--key=$kube_api_client_key \
        --endpoints=$master_ip:2379 snapshot save $ETCD_SNAPSHOT
prnt "etcd snapshot saved at $ETCD_SNAPSHOT and status is:"
etcdctl snapshot status $ETCD_SNAPSHOT --write-out=table

