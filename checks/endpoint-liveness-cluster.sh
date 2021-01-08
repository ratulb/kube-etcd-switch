#!/usr/bin/env bash
. utils.sh
api_server_etcd_url

if [ $# = 0 ]; then
  if [ -z "$debug" ]; then
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$API_SERVER_ETCD_URL member list 2>/dev/null
  else
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$API_SERVER_ETCD_URL member list
  fi
  if [ ! $? = 0 ]; then
    err "etcd endpoint list failed - can not proceed"
    return 1
  fi
  prnt "etcd endpoint is up"
else
  i=$1
  secs=$2
  status=1
  while [[ "$i" -gt 0 ]] && [[ ! "$status" = 0 ]]; do
    if [ -z "$debug" ]; then
      ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
        --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
        --endpoints=$API_SERVER_ETCD_URL member list 2>/dev/null
    else
      ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
        --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
        --endpoints=$API_SERVER_ETCD_URL member list
    fi

    status=$?
    if [ "$status" = 0 ]; then
      prnt "etcd endpoint is up"
    else
      err "etcd endpoint is not up yet - would again after $secs seconds"
      sleep $secs
      i=$((i - 1))
    fi
  done
  if [ "$status" = 0 ]; then
    echo ""
    #prnt "etcd endpoint is up now"
  else
    err "etcd endpoint list failed after $1 tries"
    return 1
  fi
fi
