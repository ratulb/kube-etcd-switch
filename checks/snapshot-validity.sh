#!/usr/bin/env bash
etcdctl snapshot status --write-out=table $1 || exit_code=$?
if ((exit_code != 0)); then
  err "Status check on the snapshot $(basename$1) failed!"
  return $exit_code
else
  prnt "etcd snapshot $1 status passed!"
fi
