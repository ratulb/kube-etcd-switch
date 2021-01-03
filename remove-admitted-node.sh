#!/usr/bin/env bash
. utils.sh

ip=$1
member_id=$(. checks/endpoint-liveness-cluster.sh 1 1 | grep started | grep $ip | cut -d ',' -f1 | xargs)
warn "Removing member: $member_id"
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=$kube_api_etcd_client_cert --key=$kube_api_etcd_client_key --endpoints=$API_SERVER_ETCD_URL:2379 member remove $member_id

if [ "$?" -eq 0 ]; then
  prnt "Etcd host($ip) removed"
  . stop-external-etcds.sh "" $ip
else
  err "Failed to remove host $ip from etcd cluster."
fi
