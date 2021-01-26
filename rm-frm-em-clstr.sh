#!/usr/bin/env bash
. utils.sh
if ! embedded_etcd_endpoints; then
  return 1
else
  debug "Removing embedded etcd member $1"
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
    --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
    --endpoints=$EMBEDDED_ETCD_ENDPOINTS member remove $1
  if [ "$?" -eq 0 ]; then
    prnt "Removed member $1"
  else
    err "Etcd member remove error"
    return 1
  fi
fi
