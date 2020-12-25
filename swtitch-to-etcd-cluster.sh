#!/usr/bin/env bash
. utils.sh

cat $kube_vault/kube-apiserver.yaml.encoded | base64 -d >  kube.draft

api_server_etcd_url

current_url=https://127.0.0.1:2379
cluster_etcd_url=$API_SERVER_ETCD_URL

sed -i "s|$current_url|$cluster_etcd_url|g" kube.draft
token=''
gen_token token

if [ "$this_host_ip" = $master_ip ]; then
  mv kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    kube.draft $master_ip:/etc/systemd/system/kube-apiserver.yaml

fi
. stop-embedded-etcd.sh
. start-external-etcds.sh


