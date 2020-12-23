#!/usr/bin/env bash
. checks/cluster-state.sh
. checks/confirm-use-clustered-etcd.sh
. utils.sh

if [ "$cluster_state" -ne 2 ]; then #We are at some other state than running external etcd cluster
  ./checks/last-good-state.sh 2
  if [ "$?" -eq 0 ]; then
    #Last good state exists - try resurrecting it
    echo "resurrecting"
  else
    echo "Would restore snapshot - because last good state is not there"
    . etcd-snapshot-migrator.sh
  fi
else
  echo "We are already in external etcd - would restore last snapshot"
fi
