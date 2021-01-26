#!/usr/bin/env bash
. utils.sh
. checks/ca-cert-existence.sh
. checks/client-cert-existence.sh
. checks/ep-state-embedded.sh

if [ "$?" -eq 0 ]; then
  snapshot_name=$1
  if [ -z "$snapshot_name" ]; then
    err "Snapshot name is empty - Not processing request"
    return 1
  fi
  snapshot_name="$snapshot_name-em"
  next_snapshot $snapshot_name

  ETCD_SNAPSHOT=$NEXT_SNAPSHOT
  SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
  mkdir -p $SNAPSHOT_DIR

  . checks/confirm-action.sh "Proceed(y)" "Cancelled snapshot save."
  if [ "$?" -eq 0 ]; then
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$EMBEDDED_ETCD_ENDPOINT snapshot save $ETCD_SNAPSHOT &>/tmp/snapshot-save-mgs.txt
    echo ""
    prnt "etcd snapshot saved at $(basename $ETCD_SNAPSHOT) and status is:"
    etcdctl snapshot status $ETCD_SNAPSHOT --write-out=table
  fi
else
  err "Snapshot save failed"
  return 1
fi
