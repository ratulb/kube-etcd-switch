#!/usr/bin/env bash
. utils.sh

last_snapshot $1

if [ ! -f "$LAST_SNAPSHOT" ]; then
  last_snapshot $2
fi

chosen_snapshot=${ETCD_SNAPSHOT:-$LAST_SNAPSHOT}
if [ ! -f "$chosen_snapshot" ]; then
  err "$0 - snapshot($chosen_snapshot) does not exists!"
  exit 1
fi

etcdctl snapshot status --write-out=table $chosen_snapshot || exit_code=$?
if ((exit_code != 0)); then
  err "Status check on the snapshot $chosen_snapshot failed!"
  exit $exit_code
else
  prnt "etcd snapshot $chosen_snapshot passed status check!"
fi

export ETCD_SNAPSHOT=$chosen_snapshot
