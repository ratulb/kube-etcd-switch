#!/usr/bin/env bash
. utils.sh

if external_etcd_endpoints; then
  if [ "$#" -ne 1 ]; then
    err "Usage: $0 snapshot file name"
    return 1
  fi
  . checks/snapshot-existence.sh
  . checks/snapshot-validity.sh
  . checks/cluster-state.sh
  etcd_snapshot=$1
  prnt "Restoring $(basename $etcd_snapshot) for external etcd."

  rm $gendir/.token &>/dev/null
  token=''
  gen_token token
  if [ "$cluster_state" = 'embedded-up' ] || [ "$cluster_state" = 'external-up' ]; then
    . save-state.sh $token
  fi
  . gen-systemd-configs.sh

  etcd_initial_cluster=$ETCD_INITIAL_CLUSTER
  for ip in $etcd_ips; do
    if can_access_ip $ip; then
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
    else
      err "Could not access host($ip) - restore artifacts not copied to!"
    fi
  done

  prnt "Restored snapshot accross etcd cluster. Will switch api server to external etcd cluster."
  #TODO
  #Remove all of the etcd ips - that were part of the embedded cluster
  #Once done swicth one the etcd servers - sync master to point to external etcd
  #Update etcd server list if required
  . switch-to-etcd-cluster.sh $etcd_ips
  . checks/system-pod-state.sh 5 3
  etcd_pods=''
  for master_name in "$masters"; do
    etcd_pods+="etcd-$master_name "
  done
  etcd_pods=$(echo $etcd_pods | xargs)
  #Need to do the following after switch - This is needed because snapshot would have etcd pod in it.
  kubectl -n kube-system delete pod $etcd_pods >/dev/null 2>&1 &

else
  err "Etcd snapshot not restord"
  return 1
fi
