#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 1 ]; then
  err "Usage: $0 snapshot file name"
  exit 1
fi
if [ -z "$etcd_ips" ]; then
  err "No etcd servers. Not proceeding with snapshot restore!"
  return 1
fi
. checks/snapshot-existence.sh
. checks/snapshot-validity.sh
. checks/cluster-state.sh
etcd_snapshot=$1
prnt "Restoring $(basename $etcd_snapshot) for external etcd."
debug "Restoring $etcd_snapshot for external etcd."

rm $gendir/.token &>/dev/null
token=''
gen_token token
if [ "$cluster_state" = 'embedded-up' ] || [ "$cluster_state" = 'external-up' ]; then
 . save-state.sh $token
fi
. gen-systemd-configs.sh

etcd_initial_cluster
etcd_initial_cluster=$ETCD_INITIAL_CLUSTER
for ip in $etcd_ips; do
  . copy-snapshot.sh $etcd_snapshot $ip
  . checks/snapshot-validity@destination.sh $ip $etcd_snapshot
  if [ "$this_host_ip" = $ip ]; then
    cp $gendir/$ip-etcd.service /etc/systemd/system/etcd.service
  else
    . copy-systemd-config.sh $ip
  fi
  next_data_dir $ip
  restore_path=$NEXT_DATA_DIR
  . restore-snapshot-cluster.sh $etcd_snapshot $restore_path $token $ip $etcd_initial_cluster
  unset restore_path
done

prnt "Restored snapshot accross etcd cluster. Will switch api server to external etcd cluster."

. switch-to-etcd-cluster.sh
. checks/endpoint-liveness-cluster.sh 5 3
. checks/system-pod-state.sh 5 3
