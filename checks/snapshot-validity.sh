#!/usr/bin/env bash
etcdctl snapshot status $1 || exit_code=$?
if ((exit_code != 0)); then
  err "Status check on the snapshot $1 failed!"
  exit $exit_code
else
  prnt "etcd snapshot $1 status passed!"
fi
