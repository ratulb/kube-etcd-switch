#!/usr/bin/env bash
. utils.sh
if [ ! -f "$etcd_ca" ] || [ ! -f "$etcd_key" ]; then
  err "Can not find etcd ca - can not proceed!"
  exit 1
fi
