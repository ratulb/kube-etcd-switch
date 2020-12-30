#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 'etcd data directory' 'intial cluster token'"
  exit 1
fi
data_dir=$1
token=$2

cat $kube_vault/etcd.yaml.encoded | base64 -d > etcd.draft
current_data_dir=$(cat etcd.draft | grep '\- --data-dir' | cut -d '=' -f 2)
sed -i "s|$current_data_dir|$data_dir|g" etcd.draft
#initial-cluster-token
sed -i '/initial-cluster-token/d' etcd.draft
sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=$token" etcd.draft

cat $kube_vault/kube-apiserver.yaml.encoded | base64 -d > kube.draft
current_etcd_url=$(cat kube.draft | grep "\- --etcd-servers" | cut -d '=' -f 2)
embedded_etcd_url=https://127.0.0.1:2379,https://$master_ip:2379
sed -i "s|$current_etcd_url|$embedded_etcd_url|g" kube.draft
if [ "$this_host_ip" = $master_ip ]; then
  cp etcd.draft /etc/kubernetes/manifests/etcd.yaml
  cp kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  sudo -u $usr scp etcd.draft $1:/etc/kubernetes/manifests/etcd.yaml
  sudo -u $usr scp kube.draft $1:/etc/kubernetes/manifests/kube-apiserver.yaml
fi


