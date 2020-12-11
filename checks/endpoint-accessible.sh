#!/usr/bin/env bash
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=$kube_api_etcd_client_cert \
  --key=$kube_api_etcd_client_key \
  --endpoints=$master_ip:2379 member list
if [ ! $? = 0 ]; then
  err "etcd endpoint list failed - can not restore!"
  exit 1
fi
