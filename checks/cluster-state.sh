#!/usr/bin/env bash
. utils.sh
cluster_state=''
kube_master=${master_ip:-$1}

kubectl cluster-info --request-timeout "30s"

cluster_up=$?

sudo -u $usr ssh $kube_master ls /etc/kubernetes/manifests/etcd.yaml &>/dev/null
etcd_yaml_present=$?

if [ "$cluster_up" = 0 -a "$etcd_yaml_present" = 0 ]; then
  state_desc="Cluster is running on embedded etcd"
  debug "$state_desc"
  export $state_desc
  export cluster_state=1
  
fi

if [ "$cluster_up" = 0 -a "$etcd_yaml_present" != 0 ]; then
  state_desc="Cluster is running on external etcd"
  debug "$state_desc"
  export $state_desc
  export cluster_state=2
fi

if [ "$cluster_up" != 0 -a "$etcd_yaml_present" = 0 ]; then
  state_desc="Cluster not runnig but configured for embedded etcd"
  debug "$state_desc"
  export $state_desc
  export cluster_state=3
fi

if [ "$cluster_up" != 0 -a "$etcd_yaml_present" != 0 ]; then
  state_desc="Cluster not runnig and not configured for embedded etcd"
  debug "$state_desc"
  export $state_desc
  export cluster_state=4
fi
