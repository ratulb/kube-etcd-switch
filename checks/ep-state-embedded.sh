#!/usr/bin/env bash
. utils.sh
if ! emd_etcd_endpoints; then
  return 1
else
  debug "Checking embedded cluster endpoins..."
  rm -f /tmp/embedded-etcd-ep-status.txt
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
    --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
    --endpoints=$EMBEDDED_ETCD_ENDPOINTS member list | tee /tmp/embedded-etcd-ep-status.txt
  if [ "$?" -eq 0 ]; then
    end_point=$(cat /tmp/embedded-etcd-ep-status.txt | head -n 1 | cut -d',' -f5 | xargs)
    export EMBEDDED_ETCD_ENDPOINT=$end_point
  else
    err "Etcd member list error"
    return 1
  fi
fi
