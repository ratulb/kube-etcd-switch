#!/usr/bin/env bash

. utils.sh
. checks/ca-cert-existence.sh
. checks/client-cert-existence.sh

latest_snapshot

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$LATEST_SNAPSHOT}
. checks/snapshot-existence.sh $ETCD_SNAPSHOT
. checks/snapshot-validity.sh $ETCD_SNAPSHOT

./copy-snapshot.sh $ETCD_SNAPSHOT $master_ip
. checks/snapshot-validity@destination.sh $master_ip $ETCD_SNAPSHOT 

next_data_dir $master_ip
RESTORE_PATH=${RESTORE_PATH:-$NEXT_DATA_DIR}
purge_restore_path $master_ip $RESTORE_PATH

rm .token
token=''
gen_token token

prnt "Restoring at location: ${RESTORE_PATH}"

./snapshot-restore.sh $ETCD_SNAPSHOT $RESTORE_PATH $token $master_ip
#TODO
echo 'y'|./etcd-draft-review.sh $RESTORE_PATH $token
./pause-api-server.sh $master_ip
./stop-etcd-cluster.sh
./reconfig-etcd.sh $master_ip
./checks/endpoint-liveness.sh 5 3
./resume-api-server.sh $master_ip
./checks/system-pod-state.sh 5 3
