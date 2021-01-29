#!/usr/bin/env bash
. utils.sh

master_ip=$1
if [ "$this_host_ip" = "$master_ip" ]; then
  cp /etc/kubernetes/manifests/kube-apiserver.yaml kube.draft
else
  remote_copy $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml kube.draft
fi
ext_etcd_endpoints
current_url=$(cat kube.draft | grep "\- --etcd-servers" | cut -d '=' -f 2)
cluster_etcd_url=$EXTERNAL_ETCD_ENDPOINTS
sed -i "s|$current_url|$cluster_etcd_url|g" kube.draft

if [ "$this_host_ip" = "$master_ip" ]; then
  mv kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  remote_copy kube.draft $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml
fi
rm -f kube.draft
