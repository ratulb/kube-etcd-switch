#!/usr/bin/env bash
. utils.sh

if emd_etcd_endpoints; then
  if [ $# = 0 ]; then
      etcd_cmd --endpoints=$EMBEDDED_ETCD_ENDPOINTS member list
    if [ ! $? = 0 ]; then
      err "etcd endpoint list failed"
      return 1
    fi
    prnt "etcd endpoint is up."
    rm -f etcd.draft
  else
    i=$1
    secs=$2
    status=1
    while [ "$i" -gt 0 ] && [[ ! "$status" = 0 ]]; do
        etcd_cmd --endpoints=$EMBEDDED_ETCD_ENDPOINTS member list

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
      rm -f etcd.draft
    else
      err "etcd endpoint list failed after $1 tries."
    fi
  fi
else
  err "No master(s) found - Has the system been initialized"
fi
