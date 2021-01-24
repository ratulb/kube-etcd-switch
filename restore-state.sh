#!/usr/bin/env bash
. utils.sh

if [ -z $1 ]; then
  err "Usage $0 embedded-up|external-up|matching prefix|listed fileName."
  exit 1
fi
last_saved_state $1

SAVED_FILE="$LAST_SAVE"
if [ ! -f "$SAVED_FILE" ]; then
  err "Saved state not found - Can not proceed!"
  return 1
fi

prnt "Preparing state restore..."
if [ "$cluster_state" == 'embedded-up' ]; then
  . stop-embedded-etcd.sh
fi
if [ "$cluster_state" == 'external-up' ]; then
  . stop-external-etcds.sh
fi

tar xvf "$SAVED_FILE" -C "$kube_vault"
debug "Prcocessing last good system states in $SAVED_FILE"

for file_path in "$kube_vault"/system-snaps/*.tar.gz; do
  file_name=$(basename "$file_path")
  ip=$(echo "$file_name" | cut -d '-' -f 1)
  if [ "$ip" = "$this_host_ip" ]; then
    tar xvf "$file_path" -C /
  else
    sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      $file_path $ip:$kube_vault/system-snap/system-snap.tar.gz
    . execute-script-remote.sh $ip unarchive.script
    remote_cmd $ip "rm -rf $kube_vault/system-snap/system-snap.tar.gz"
  fi
  debug "Restored $file_path on $ip"
  prnt "Restored last good state in $ip"
done
rm -rf "$kube_vault"/system-snaps/*

prnt "Last good states restored on cluster machines"

prnt "Resurrecting etcd"
state=$(echo "$SAVED_FILE" | xargs basename | cut -d '#' -f 1)
case "$state" in
  embedded-up)
    . stop-external-etcds.sh
    . checks/endpoint-liveness.sh 5 3
    ;;
  external-up)
    . stop-embedded-etcd.sh
    . start-external-etcds.sh
    . checks/endpoint-liveness-cluster.sh 5 3
    ;;
  *) ;;
esac
. checks/system-pod-state.sh 5 3
