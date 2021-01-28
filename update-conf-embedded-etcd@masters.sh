#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 'etcd data directory' 'intial cluster token' 'master node ip"
  return 1
fi
data_dir=$1
token=$2
_master_ip=$3

if [ "$_master_ip" = "$this_host_ip" ]; then
  cp /etc/kubernetes/manifests/etcd.yaml etcd.draft
  cp /etc/kubernetes/manifests/kube-apiserver.yaml kube.draft
else
  remote_copy $_master_ip:/etc/kubernetes/manifests/etcd.yaml etcd.draft
  remote_copy $_master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml kube.draft
fi
#TODO Need a stronger/fail proof way to do find replace
mount_path=$(cat etcd.draft | grep volumeMounts: -A1 | grep '\- mountPath:' | xargs | cut -d' ' -f3)
sed -i "s|$mount_path|$data_dir|g" etcd.draft
host_path=$(cat etcd.draft | tail -n4 | grep path: | xargs | cut -d' ' -f2)
sed -i "s|$host_path|$data_dir|g" etcd.draft
current_data_dir=$(cat etcd.draft | grep '\- --data-dir' | cut -d '=' -f 2)
sed -i "s|$current_data_dir|$data_dir|g" etcd.draft
#initial-cluster-token
sed -i '/initial-cluster-token/d' etcd.draft
sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=$token" etcd.draft
current_etcd_url=$(cat kube.draft | grep "\- --etcd-servers" | cut -d '=' -f 2)
embedded_etcd_url=https://127.0.0.1:2379,https://$_master_ip:2379
sed -i "s|$current_etcd_url|$embedded_etcd_url|g" kube.draft
if [ "$this_host_ip" = $_master_ip ]; then
  cp etcd.draft /etc/kubernetes/manifests/etcd.yaml
  cp kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  remote_copy etcd.draft $_master_ip:/etc/kubernetes/manifests/etcd.yaml
  remote_copy kube.draft $_master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml
fi

rm -f etcd.draft
rm -f kube.draft
