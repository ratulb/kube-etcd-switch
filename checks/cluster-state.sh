#!/usr/bin/env bash
. utils.sh
CLUSTER_STATE=''
kube_master=${master_ip:-$1}

kubectl cluster-info &>/dev/null
cluster_up=$?

sudo -u $usr ssh $kube_master ls /etc/kubernetes/manifests/etcd.yaml &>/dev/null
etcd_yaml_present=$?

if [ "$cluster_up" = 0 -a "$etcd_yaml_present" = 0 ]; then
  debug "Cluster is running on embedded etcd"
  export CLUSTER_STATE=1000
fi

if [ "$cluster_up" = 0 -a "$etcd_yaml_present" != 0 ]; then
  debug "Cluster is running on external etcd"
  export CLUSTER_STATE=2000
fi

if [ "$cluster_up" != 0 -a "$etcd_yaml_present" = 0 ]; then
  debug "Cluster not runnig but configured for embedded etcd"
  export CLUSTER_STATE=3000
fi

if [ "$cluster_up" != 0 -a "$etcd_yaml_present" != 0 ]; then
  debug "Cluster not runnig and not configured for embedded etcd"
  export CLUSTER_STATE=4000
fi
