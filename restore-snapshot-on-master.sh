#!/usr/bin/env bash
. utils.sh

. checks/choose-snapshot.sh embedded-etcd external-etcd
. checks/confirm-action.sh "Proceed with move" "move"
. checks/cluster-state.sh

#Save the system state - if currently up - will use prev token if exists
if [ "$cluster_state" = 'external-up' ] || [ "$cluster_state" = 'embedded-up' ]; then
  . archive-system-states.sh
fi

. copy-snapshot.sh $ETCD_SNAPSHOT $master_ip
. checks/snapshot-validity@destination.sh $master_ip $ETCD_SNAPSHOT

next_data_dir $master_ip
RESTORE_PATH=${RESTORE_PATH:-$NEXT_DATA_DIR}

rm $gendir/.token &>/dev/null
token=''
gen_token token

prnt "Restoring at location: ${RESTORE_PATH}"

. restore-snapshot.sh $ETCD_SNAPSHOT $RESTORE_PATH $token $master_ip
echo 'y' | ./etcd-draft-review.sh $RESTORE_PATH $token
. stop-external-etcds.sh
. apply-etcd-draft.sh $master_ip
. checks/endpoint-liveness.sh 5 3
. checks/system-pod-state.sh 5 3
