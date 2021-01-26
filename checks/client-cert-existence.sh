#!/usr/bin/env bash
if [ ! -f "/etc/kubernetes/pki/etcd/$(hostname)-client.crt" ] || [ ! -f "/etc/kubernetes/pki/etcd/$(hostname)-client.key" ]; then
  err "API client cert/key missing!"
  return 1
fi
