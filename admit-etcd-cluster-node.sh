#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 hostname host-ip-address"
  exit 1
fi

host=$1
ip=$2
host_and_ip=$1:$2

. checks/cluster-state.sh
if [ "$cluster_state" != "external-up" ]; then
  err "etcd cluster is offline or not setup - Can not add node."
  exit 1
fi
. checks/endpoint-liveness-cluster.sh 1 1 | grep started | grep $host | grep $ip
if [ "$?" -eq 0 ]; then
  prnt "$host_and_ip is already part of the cluster!"
  exit 0
fi
prnt "Adding node($host) with ip($ip) to etcd cluster"

ETCD_INITIAL_CLUSTER=$(ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=$kube_api_etcd_client_cert --key=$kube_api_etcd_client_key --endpoints=$API_SERVER_ETCD_URL:2379 member add $host --peer-urls=https://$ip:2380 | grep "ETCD_INITIAL_CLUSTER")

debug "$0 cluster add member respose etcd initial url:  $ETCD_INITIAL_CLUSTER"

if [ ! -z "$ETCD_INITIAL_CLUSTER" ]; then
  prnt "Cluster accepted request for node addition($host_and_ip) - going to bring up server!"
  initial_cluster_url=$(echo $ETCD_INITIAL_CLUSTER | cut -d '"' -f2)
  . gen-systemd-config.sh $host $ip $initial_cluster_url
  if can_access_ip $ip; then
    if [ "$this_host_ip" = $ip ]; then
      cp $gendir/$ip-etcd.service /etc/systemd/system/etcd.service
    else
      . copy-systemd-config.sh $ip
    fi
    prnt "Starting etcd for cluster admitted etcd($host_and_ip)"
    . start-external-etcds.sh $ip
  else
    err "Could not access host($ip) - restore artifacts not copied to!"
  fi
else
  err "Failed to add node($host) with ip($ip) to etcd cluster"
fi
