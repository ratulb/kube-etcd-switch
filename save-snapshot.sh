#!/usr/bin/env bash

. utils.sh
. checks/ca-cert-existence.sh
. checks/client-cert-existence.sh
. checks/endpoint-liveness.sh 1 1
. checks/cluster-state.sh

snapshot_name=$1
snapshot_name=${snapshot_name:-$cluster_state}

next_snapshot $snapshot_name

ETCD_SNAPSHOT=$NEXT_SNAPSHOT
SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
mkdir -p $SNAPSHOT_DIR

. checks/confirm-action.sh "Proceed(y)" "Cancelled snapshot save."
if [ "$?" -eq 0 ]; then
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
    --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
    --endpoints=$master_address:2379 snapshot save $ETCD_SNAPSHOT &>/dev/null
  echo ""
  prnt "etcd snapshot saved at $(basename $ETCD_SNAPSHOT) and status is:"
  etcdctl snapshot status $ETCD_SNAPSHOT --write-out=table
fi
