#!/usr/bin/env bash
. utils.sh

if [ -z $1 ]; then
  err "Usage $0 embedded-up|external-up"
  exit 1
fi
last_archived_state $1

ARCHIVED_FILE=${USER_ARCHIVE:-$LAST_ARCHIVE}
debug "Archived file : $ARCHIVED_FILE"
if [ ! -f $ARCHIVED_FILE ]; then 
 err "$ARCHIVED_FILE file not found - Can not proceed!"
 exit 1
fi

tar xvf $ARCHIVED_FILE -C $kube_vault
prnt "Prcocessing last good system states $ARCHIVED_FILE"

for file_path in $kube_vault/system-snaps/*.tar.gz; do
  file_name=$(basename $file_path)
  ip=$(echo "$file_name" | cut -d '-' -f 1)
  if [ "$ip" = "$this_host_ip" ]; then
    tar xvf $file_path -C /
  else
    sudo -u $usr scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      $file_path $ip:$kube_vault/system-snap/system-snap.tar.gz
    . execute-script-remote.sh $ip unarchive.script
    sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $ip "rm -rf $kube_vault/system-snap/system-snap.tar.gz"
  fi
  debug "Untarred $file_path on $ip"
  prnt "Restored last good state in $ip"
done
rm -rf $kube_vault/system-snaps/*

prnt "Last good states restored on cluster machines"