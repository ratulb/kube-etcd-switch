#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 1 ]; then
  err "Usage: ./restore-snapshot@masters.sh 'snapshot file name'"
  return 1
fi
. checks/snapshot-existence.sh
. checks/snapshot-validity.sh
etcd_snapshot=$1
prnt "Restoring $(basename $etcd_snapshot) for embedded etcd."
debug "Restoring $etcd_snapshot for embedded etcd."

rm $gendir/.token &>/dev/null
token=''
gen_token token
. checks/cluster-state.sh
if [ "$cluster_state" = 'external-up' ] || [ "$cluster_state" = 'embedded-up' ]; then
  . save-state.sh $token
fi

if [ ! -z "$masters" ]; then
  for _mstr_ip in $masters; do
    debug "Restoring $(basename $etcd_snapshot) for master member $_mstr_ip"
    . copy-snapshot.sh $etcd_snapshot $_mstr_ip
    . checks/snapshot-validity@destination.sh $_mstr_ip $etcd_snapshot

    next_data_dir $_mstr_ip
    restore_path=$NEXT_DATA_DIR

    debug "Restoring at location: ${restore_path} for master member $_mstr_ip"

    . restore-snapshot.sh $etcd_snapshot $restore_path $token $_mstr_ip
    . remove-admitted-node.sh $_mstr_ip
    unset _hostname
    if is_address_local $_mstr_ip; then
      _hostname=$this_host_name
    else
      _hostname=$(remote_cmd $_mstr_ip hostname)
    fi
    prune_etcd_server_list "$_hostname:$_mstr_ip"
    . stop-external-etcds.sh $_mstr_ip
    . update-conf-embedded-etcd@masters.sh $restore_path $token $_mstr_ip
  done
  . checks/endpoint-liveness.sh 5 3
  . checks/system-pod-state.sh 5 3
else
  err "No master(s) found - Has the system been initialized?"
  return 1
fi
