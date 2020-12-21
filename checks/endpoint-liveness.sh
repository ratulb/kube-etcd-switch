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
  echo -e "\e[1;42metcd endpoint is up.\e[0m"
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
    if [ "$status" = 0 ]; then
      echo -e "\e[1;42metcd endpoint is up.\e[0m"
      rm -f etcd.draft
    fi
    echo -e "\e[31metcd endpoint is not up - would again after $secs seconds!\e[0m"
    sleep $secs
    i=$((i - 1))
  done
  if [ "$status" = 0 ]; then
    echo -e "\e[1;42metcd endpoint is up.\e[0m"
    rm -f etcd.draft
  else
    echo -e "\e[31metcd endpoint list failed after $1 tries.Can not proceed!\e[0m"
  fi
fi
