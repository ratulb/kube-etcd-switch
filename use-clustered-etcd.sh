#!/usr/bin/env bash
. utils.sh

. checks/cluster-state.sh
. checks/confirm-use-clustered-etcd.sh

if [ ! "$cluster_state" = 'external-up' ]; then #We are at some other state than running external etcd cluster
  if saved_state_exists external-up; then
    . stop-embedded-etcd.sh
    . restore-state.sh 'external-up'
    . start-external-etcds.sh
    . checks/system-pod-state.sh 5 3
  else
    prnt "Would restore snapshot - because last good state is not present!"
    . restore-snapshot@nodes.sh
  fi
else
  prnt "We are already in external etcd - would restore last snapshot"
  . restore-snapshot@nodes.sh
fi
