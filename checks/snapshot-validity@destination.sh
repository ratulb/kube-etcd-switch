#!/usr/bin/env bash
. utils.sh

if [ "$this_host_ip" != $1 ]; then
  remote_cmd $1 "etcdctl snapshot status --write-out=table $2 || exit_code=$?"
  if ((exit_code != 0)); then
    err "Status check on the snapshot $(basename $2) failed on host($1)."
    debug "Status check on the snapshot $2 failed on host($1)."
    return $exit_code
  else
    prnt "Snapshot $(basename $2) passed validity check on host($1)."
    debug "Snapshot $2 passed validity check on host($1)."
  fi
fi
