#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 1 ]; then
  err "Usage: $0 snapshot file name"
  exit 1
fi
. checks/snapshot-existence.sh
. checks/snapshot-validity.sh
. checks/cluster-state.sh
etcd_snapshot=$1
prnt "Restoring $etcd_snapshot for embedded etcd."

rm $gendir/.token &>/dev/null
token=''
gen_token token
if [ "$cluster_state" = 'external-up' ] || [ "$cluster_state" = 'embedded-up' ]; then
  . save-state.sh $token
fi


. copy-snapshot.sh $etcd_snapshot $master_ip
. checks/snapshot-validity@destination.sh $master_ip $etcd_snapshot

next_data_dir $master_ip
restore_path=${RESTORE_PATH:-$NEXT_DATA_DIR}

prnt "Restoring @location: ${restore_path}"

. restore-snapshot.sh $etcd_snapshot $restore_path $token $master_ip
echo 'y' | ./etcd-draft-review.sh $restore_path $token
. stop-external-etcds.sh
. apply-etcd-draft.sh $master_ip
. checks/endpoint-liveness.sh 5 3
. checks/system-pod-state.sh 5 3