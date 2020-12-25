#!/usr/bin/env bash
. utils.sh
api_server_etcd_url

if [ $# = 0 ]; then
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
	  --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
    --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
    --endpoints=$API_SERVER_ETCD_URL member list
  if [ ! $? = 0 ]; then
    echo -e "\e[31metcd endpoint list failed - can not proceed!\e[0m"
    exit 1
  fi
  echo -e "\e[1;42metcd endpoint is up.\e[0m"
  rm -f etcd.draft
else
  i=$1
  secs=$2
  status=1
  while [ "$i" > 0 ] && [[ ! "$status" = 0 ]]; do
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$API_SERVER_ETCD_URL member list

    status=$?
    if [ "$status" = 0 ]; then
      echo -e "\e[1;42metcd endpoint is up.\e[0m"
      rm -f etcd.draft
      exit 0
    fi
    echo -e "\e[31metcd endpoint is not up - would again after $secs seconds!\e[0m"
    sleep $secs
    i=$((i - 1))
  done
  if [ "$status" = 0 ]; then
    echo -e "\e[1;42metcd endpoint is up.\e[0m"
    rm -f etcd.draft
    exit 0
  else
    echo -e "\e[31metcd endpoint list failed after $1 tries.Can not proceed!\e[0m"
    exit 1
  fi
fi
