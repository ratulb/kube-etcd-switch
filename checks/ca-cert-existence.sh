#!/usr/bin/env bash
. utils.sh
if [ ! -f "$etcd_ca" ] || [ ! -f "$etcd_key" ]; then
  err "Can not find etcd ca - can not proceed! Has the system been initialized?"
  exit 1
fi
