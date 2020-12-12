#!/usr/bin/env bash
. utils.sh
  if [ "$#" -ne 4 ]; then
    echo "Usage: $0 'snapshot db file' 'data dir' 'intial cluster token' 'IP'"
    exit 1
  fi
  snapshot_file=$1
  data_dir=$2
  initial_cluster_token=$3
  machine_ip=$4
  this_host_ip=$(hostname -i)

  cp etcd-restore.script restore.script
  sed -i "s|#ETCD_SNAPSHOT#|$snapshot_file|g" restore.script
  sed -i "s|#RESTORE_PATH#|$data_dir|g" restore.script
  sed -i "s|#TOKEN#|$initial_cluster_token|g" restore.script

  cat restore.script
  
  if [ "$this_host_ip" = $machine_ip ]; 
    then
      ./restore.script
    else
      . execute-script-remote.sh $machine_ip restore.script
  fi
  exit_code=$?
  if [ $exit_code != 0 ]; then
    err "Snapshot restore failed!"
    exit $exit_code
  fi
  prnt "Snapshot($snapshot_file) has been applied @$data_dir in machine($machine_ip) successfully"
  #TODO
  #rm restore.script
