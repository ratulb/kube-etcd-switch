#!/usr/bin/env bash
. utils.sh

. checks/choose-snapshot.sh external-etcd embedded-etcd
. checks/snapshot-existence.sh $ETCD_SNAPSHOT
. checks/snapshot-validity.sh $ETCD_SNAPSHOT

. checks/confirm-action.sh "Proceed with move" "move"
. checks/cluster-state.sh

#Save good state for embedded etcd
if [ $cluster_state -eq 1 ]; then
 . system-archiver.sh 
fi

. gen-systemd-configs.sh

token=''
gen_token token
etcd_initial_cluster

for ip in $etcd_ips; do
  . copy-snapshot.sh $ETCD_SNAPSHOT $ip
  . checks/snapshot-validity@destination.sh $ip $ETCD_SNAPSHOT
  if [ $this_host_ip = $ip ]; then
    mv /etc/systemd/system/etcd.service $HOME/.kube_vault/$token-etcd.service
    cp $(pwd)/generated/$ip-etcd.service /etc/systemd/system/etcd.service
  else
    . copy-systemd-config.sh $ip
  fi
  next_data_dir $ip
  RESTORE_PATH=${RESTORE_PATH:-$NEXT_DATA_DIR}
  . restore-snapshot-cluster.sh $ETCD_SNAPSHOT $RESTORE_PATH $token $ip $ETCD_INITIAL_CLUSTER
  unset RESTORE_PATH
done

prnt "Done snapshot restore accross etcd cluster. Will switch api server to external etcd cluster..."

. swtitch-to-etcd-cluster.sh

. checks/endpoint-liveness-cluster.sh

. checks/system-pod-state.sh 5 3
