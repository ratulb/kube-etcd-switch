#!/usr/bin/env bash
. utils.sh
if ! ext_etcd_endpoints; then
  return 1
else
  debug "Adding external etcd member $1"
  rm -f /tmp/external-etcd-member-adding-resp.txt
  etcd_cmd --endpoints=$EXTERNAL_ETCD_ENDPOINTS member add $1 --peer-urls=https://$2:2380
  if [ "$?" -eq 0 ]; then  
  prnt "Added member $1"
  else
    err "Etcd member add error"
    return 1
  fi
fi
