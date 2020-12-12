#!/usr/bin/env bash
if [ ! -f "$etcd_ca" ] || [ ! -f "$etcd_key" ]; then
  err "etcd ca/key not setup!"
  exit 1
fi

