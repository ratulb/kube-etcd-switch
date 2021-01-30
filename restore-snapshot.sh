#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 'snapshot db file' 'data dir' 'intial cluster token' 'ip', 'initial-cluster'"
  return 1
fi
snapshot_file=$1
data_dir=$2
initial_cluster_token=$3
node_ip=$4
initial_cluster=$5

dress_up_script etcd-restore.script $snapshot_file $data_dir \
  $initial_cluster_token $initial_cluster
if [ "$this_host_ip" = "$node_ip" ]; then
  . etcd-restore.script.tmp
else
  remote_script $node_ip etcd-restore.script.tmp
fi
exit_code=$?
if [ $exit_code != 0 ]; then
  err "Snapshot restore failed!"
  return $exit_code
fi
prnt "Snapshot $snapshot_file has been applied at node($node_ip) successfully"
