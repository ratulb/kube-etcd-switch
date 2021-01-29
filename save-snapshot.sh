#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 2 ]; then
  err "Usage: ./save-snapshot.sh 'snapshot name' 'from cluster'"
  return 1
fi
if ca_exists && client_cert_exists; then
  snapshot_name=$1
  cluster=$2
  unset endpoint
  if [[ "$cluster" = 'embedded' ]] && em_ep_state_and_list; then
    endpoint=$EMBEDDED_ETCD_ENDPOINT
    snapshot_name="$snapshot_name-em"
  elif [[ "$cluster" = 'external' ]] && ex_ep_state_and_list; then
    endpoint=$EXTERNAL_ETCD_ENDPOINT
    snapshot_name="$snapshot_name-ext"
  else
    err "No endpoints - snapshot not saved" && return 1
  fi

  next_snapshot $snapshot_name

  ETCD_SNAPSHOT=$NEXT_SNAPSHOT
  SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
  mkdir -p $SNAPSHOT_DIR

  . checks/confirm-action.sh "Proceed(y)" "Cancelled snapshot save."
  if [ "$?" -eq 0 ]; then
     etcd_cmd --endpoints=$endpoint snapshot save $ETCD_SNAPSHOT &>/tmp/snapshot-save-mgs.txt
    echo ""
    prnt "etcd snapshot saved at $(basename $ETCD_SNAPSHOT) and status is:"
    etcdctl snapshot status $ETCD_SNAPSHOT --write-out=table
  fi
else
  err "Snapshot save failed due to certificate issue"
  return 1
fi
