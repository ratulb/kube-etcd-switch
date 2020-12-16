#!/usr/bin/env bash

. utils.sh

last_snapshot

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$LAST_SNAPSHOT}
. checks/snapshot-existence.sh $ETCD_SNAPSHOT
. checks/snapshot-validity.sh $ETCD_SNAPSHOT

rm -f .token

. gen-systemd-configs.sh

token=''
gen_token token
etcd_initial_cluster

this_host_ip=$(echo $(hostname -i) | cut -d ' ' -f 1)

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

. swtitch-to-external-cluster.sh 

. checks/endpoint-liveness-cluster.sh

. checks/system-pod-state.sh 5 3

