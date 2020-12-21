#!/usr/bin/env bash
. checks/cluster-state.sh
. checks/confirm-use-embedded-etcd.sh
. utils.sh
. checks/ca-cert-existence.sh
. checks/client-cert-existence.sh

last_snapshot

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$LAST_SNAPSHOT}
. checks/snapshot-existence.sh $ETCD_SNAPSHOT
. checks/snapshot-validity.sh $ETCD_SNAPSHOT

read -p "Confirm move?" -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  err "\nAborted move.\n"
  exit 1
fi

. copy-snapshot.sh $ETCD_SNAPSHOT $master_ip
. checks/snapshot-validity@destination.sh $master_ip $ETCD_SNAPSHOT 

next_data_dir $master_ip
RESTORE_PATH=${RESTORE_PATH:-$NEXT_DATA_DIR}
purge_restore_path $master_ip $RESTORE_PATH

rm .token &> /dev/null
token=''
gen_token token

prnt "Restoring at location: ${RESTORE_PATH}"

. restore-snapshot.sh $ETCD_SNAPSHOT $RESTORE_PATH $token $master_ip
#TODO what?
echo 'y'|./etcd-draft-review.sh $RESTORE_PATH $token
. pause-api-server.sh
. stop-etcd-cluster.sh
. apply-etcd-draft.sh $master_ip
. checks/endpoint-liveness.sh 5 3
. resume-api-server.sh
. checks/system-pod-state.sh 5 3
