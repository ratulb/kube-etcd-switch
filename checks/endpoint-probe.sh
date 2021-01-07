#!/usr/bin/env bash
. utils.sh
if [ "$#" -gt 0 ]; then
  probe_endpoints "$@"
else
  probe_endpoints
fi
if [ -z "$per_endpoint" ]; then
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
    --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
    --endpoints=$PROBE_ENDPOINTS member list 2>/dev/null
  [ "$?" -eq 0 ] && prnt "endpoint(s) up" || err "endpoint(s) down"
else
  endpoints=$PROBE_ENDPOINTS
  endpoints=$(echo $endpoints | tr "," " ")

  for endpoint in $endpoints; do
    echo ""
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$endpoint member list 2>/dev/null
    # [ "$?" -eq 0 ] && echo "member up" && exit 0 || :
    [ "$?" -eq 0 ] && prnt "$endpoint is up" || err "$endpoint is down"
  done
fi
