#!/usr/bin/env bash
. utils.sh

. checks/choose-snapshot.sh external-etcd embedded-etcd

. checks/confirm-action.sh "Proceed with move" "move"
#. checks/cluster-state.sh
#Save good state if the cluster is up
if [ "$cluster_state" = 'embedded-up' ] || [ "$cluster_state" = 'external-up' ]; then
 . archive-system-states.sh 
fi

rm $gendir/.token &>/dev/null
token=''
gen_token token

. gen-systemd-configs.sh

etcd_initial_cluster

for ip in $etcd_ips; do
  . copy-snapshot.sh $ETCD_SNAPSHOT $ip
  . checks/snapshot-validity@destination.sh $ip $ETCD_SNAPSHOT
  if [ $this_host_ip = $ip ]; then
    cp $gendir/$ip-etcd.service /etc/systemd/system/etcd.service
  else
    . copy-systemd-config.sh $ip
  fi
  next_data_dir $ip
  RESTORE_PATH=${RESTORE_PATH:-$NEXT_DATA_DIR}
  . restore-snapshot-cluster.sh $ETCD_SNAPSHOT $RESTORE_PATH $token $ip $ETCD_INITIAL_CLUSTER
  unset RESTORE_PATH
done

prnt "Restored snapshot accross etcd cluster. Will switch api server to external etcd cluster."

. swtitch-to-etcd-cluster.sh
. checks/endpoint-liveness-cluster.sh
. checks/system-pod-state.sh 5 3
