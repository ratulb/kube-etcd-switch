#!/usr/bin/env bash
prnt "Checking snapshot($2) on remote host($1)"
sudo -u $usr ssh $1 "etcdctl snapshot status $2 || exit_code=$?"
if ((exit_code != 0)); then
  err "Status check on the snapshot $2 failed!"
  exit $exit_code
else
  prnt "etcd snapshot on $2 status passed!"
fi
