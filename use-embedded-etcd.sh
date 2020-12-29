#!/usr/bin/env bash
. utils.sh

. checks/cluster-state.sh
. checks/confirm-use-embedded-etcd.sh
token=''
gen_token token
if [ ! "$cluster_state" = 'embedded-up' ]; then #We are on some other state than running embedded etcd cluster
  if saved_state_exists 'embedded-up'; then
    #Archive system if it is up
    if [ "$cluster_state" = 'external-up' ] || [ "$cluster_state" = 'embedded-up' ]; then
      . save-state.sh $token
    fi
    . stop-external-etcds.sh
    . restore-state.sh 'embedded-up'
    . checks/system-pod-state.sh 5 3
  else
    prnt "Would restore snapshot - because last good state is not there"
    . restore-snapshot@master.sh
  fi
else
  prnt "We are already in embedded etcd - would restore last snapshot"
  . restore-snapshot@master.sh
fi
