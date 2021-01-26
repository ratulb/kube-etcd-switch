#!/usr/bin/env bash
. utils.sh
if ! external_etcd_endpoints; then
  return 1
else
  debug "Removing external etcd member $1"
  rm -f /tmp/external-etcd-member-remove-resp.txt
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
    --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
    --endpoints=$EXTERNAL_ETCD_ENDPOINTS member remove $1
  if [ "$?" -eq 0 ]; then
    prnt "Removed member $1"
  else
    err "Etcd member remove error"
    return 1
  fi
fi
