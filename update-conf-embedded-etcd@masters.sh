#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 'etcd data directory' 'intial cluster token' 'master node ip' 'initial_cluster' 'master name'"
  return 1
fi
data_dir=$1
token=$2
master_ip=$3
initial_cluster=$4
master_name=$5

if [ "$master_ip" = "$this_host_ip" ]; then
  cp /etc/kubernetes/manifests/etcd.yaml etcd.draft
  cp /etc/kubernetes/manifests/kube-apiserver.yaml kube.draft
else
  remote_copy $master_ip:/etc/kubernetes/manifests/etcd.yaml etcd.draft
  remote_copy $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml kube.draft
fi
#TODO Need a stronger/fail proof way to do find replace
mount_path=$(cat etcd.draft | grep volumeMounts: -A1 | grep '\- mountPath:' | xargs | cut -d' ' -f3)
sed -i "s|$mount_path|$data_dir|g" etcd.draft
host_path=$(cat etcd.draft | tail -n4 | grep path: | xargs | cut -d' ' -f2)
sed -i "s|$host_path|$data_dir|g" etcd.draft
current_data_dir=$(cat etcd.draft | grep '\- --data-dir' | cut -d '=' -f 2)
sed -i "s|$current_data_dir|$data_dir|g" etcd.draft
sed -i '/initial-cluster/d' etcd.draft
#sed -i '/initial-cluster-token/d' etcd.draft

sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=$token" etcd.draft
sed -i "/--client-cert-auth=true/a\    \- --initial-cluster=$initial_cluster" etcd.draft
if [ "$master_ip" != "$master_address" ]; then
  :#sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-state=existing" etcd.draft
fi

current_etcd_url=$(cat kube.draft | grep "\- --etcd-servers" | cut -d '=' -f 2)
embedded_etcd_url=https://127.0.0.1:2379,https://$master_ip:2379
sed -i "s|$current_etcd_url|$embedded_etcd_url|g" kube.draft
if ! [ "$master_ip" = "$master_address" ]; then
  while ! em_ep_state_and_list; do
    : #sleep_few_secs
  done
  #etcd_cmd --endpoints=$EMBEDDED_ETCD_ENDPOINTS member list | tee /tmp/embedded_etcd_members.txt
  #etcd_cmd member add --endpoints=$EMBEDDED_ETCD_ENDPOINT $master_name --peer-urls=https://$master_ip:2380
  #sleep_few_secs

fi

if [ "$this_host_ip" = $master_ip ]; then
  cp etcd.draft /etc/kubernetes/manifests/etcd.yaml
  cp kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  remote_copy etcd.draft $master_ip:/etc/kubernetes/manifests/etcd.yaml
  remote_copy kube.draft $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml
fi
if [ "$master_ip" = "$master_address" ]; then
  :
  #sleep_few_secs
  #etcd_cmd --endpoints=$EMBEDDED_ETCD_ENDPOINTS member list | tee /tmp/embedded_etcd_members.txt
fi
rm -f etcd.draft
rm -f kube.draft
