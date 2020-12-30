#!/usr/bin/env bash
. utils.sh
if [ $# = 0 ]; then
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=$kube_api_etcd_client_cert \
    --key=$kube_api_etcd_client_key \
    --endpoints=$master_ip:2379 member list
  if [ ! $? = 0 ]; then
    echo -e "\e[31metcd endpoint list failed - can not proceed!\e[0m"
    exit 1
  fi
  prnt "etcd endpoint is up."
  rm -f etcd.draft
else
  i=$1
  secs=$2
  status=1
  while [ "$i" -gt 0 ] && [[ ! "$status" = 0 ]]; do
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=$kube_api_etcd_client_cert \
      --key=$kube_api_etcd_client_key \
      --endpoints=$master_ip:2379 member list

    status=$?
    if [ "$status" -eq 0 ]; then
      prnt "etcd endpoint is up."
      rm -f etcd.draft
    else
      err "etcd endpoint is not up yet - would again after $secs seconds!"
      sleep $secs
      i=$((i - 1))
    fi
  done
  if [ "$status" -eq 0 ]; then
    echo ""
    #prnt "etcd endpoint is up now."
    rm -f etcd.draft
  else
    err "etcd endpoint list failed after $1 tries."
  fi
fi
