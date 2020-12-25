#!/usr/bin/env bash
. utils.sh

. checks/cluster-state.sh
. checks/confirm-use-embedded-etcd.sh
if [ ! "$cluster_state" = 'embedded-up' ]; then #We are on some other state than running embedded etcd cluster
  if last_good_state_exists 'embedded-up'; then
    #Archive system if it is up
    if [ "$cluster_state" = 'external-up' ] || [ "$cluster_state" = 'embedded-up' ]; then
      . archive-system-states.sh
    fi
    . stop-external-etcds.sh
    . unarchive-system-states.sh 'embedded-up'
    . checks/system-pod-state.sh 5 3
  else
    prnt "Would restore snapshot - because last good state is not there"
    . restore-snapshot-on-master.sh
  fi
else
  prnt "We are already in embedded etcd - would restore last snapshot"
  . restore-snapshot-on-master.sh
fi
