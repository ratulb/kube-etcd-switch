#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 1 ]; then
  err "Usage: ./restore-snapshot@masters.sh 'snapshot file name'"
  return 1
fi
. checks/snapshot-existence.sh
. checks/snapshot-validity.sh
etcd_snapshot=$1
prnt "Restoring $etcd_snapshot for embedded etcd."

rm $gendir/.token &>/dev/null
token=''
gen_token token
. checks/cluster-state.sh
if [ "$cluster_state" = 'external-up' ] || [ "$cluster_state" = 'embedded-up' ]; then
  . save-state.sh $token
fi

if [ ! -z "$masters" ]; then
  emd_etcd_endpoints
  initial_cluster=$EMBEDDED_INITIAL_CLUSTER
  for master in $masters; do

    master_name=$(echo $master | cut -d':' -f1)
    master_ip=$(echo $master | cut -d':' -f2)

    next_data_dir $master_ip
    restore_path=$NEXT_DATA_DIR
    prnt "Restoring $etcd_snapshot at location: $restore_path for $master_name($master_ip)"
    initial_cluster=$EMBEDDED_INITIAL_CLUSTER
    #if [ "$master_ip" = "$master_address" ]; then
    . copy-snapshot.sh $etcd_snapshot $master_ip
    . checks/snapshot-validity@destination.sh $master_ip $etcd_snapshot
    #initial_cluster=$master_name=https://$master_ip:2380
    . restore-snapshot.sh $etcd_snapshot $restore_path $token $master_ip $initial_cluster
    #else
    #  initial_cluster=$EMBEDDED_INITIAL_CLUSTER
    # fi
    . update-conf-embedded-etcd@masters.sh $restore_path $token $master_ip $initial_cluster $master_name
  done
  . checks/endpoint-liveness.sh 5 3
  . checks/system-pod-state.sh 5 3
else
  err "No master(s) found - Has the system been initialized?"
  return 1
fi
