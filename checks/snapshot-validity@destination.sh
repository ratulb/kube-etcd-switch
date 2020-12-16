#!/usr/bin/env bash

this_host_ip=$(echo $(hostname -i) | cut -d ' ' -f 1)

if [ "$this_host_ip" != $1 ]; then
  sudo -u $usr ssh $1 "etcdctl snapshot status --write-out=table $2 || exit_code=$?"
  if ((exit_code != 0)); then
    err "Status check on the snapshot $2 failed on host($1)."
    exit $exit_code
  else
    prnt "Snapshot $2 passed validity check on host($1)."
  fi
fi
