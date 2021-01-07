#!/usr/bin/env bash
. utils.sh
cat $kube_vault/kube-apiserver.yaml.encoded | base64 -d >  kube.draft
api_server_etcd_url
current_url=$(cat kube.draft | grep "\- --etcd-servers" | cut -d '=' -f 2)
cluster_etcd_url=$API_SERVER_ETCD_URL
sed -i "s|$current_url|$cluster_etcd_url|g" kube.draft

if [ "$this_host_ip" = $master_ip ]; then
  mv kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    kube.draft $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml
fi
. stop-embedded-etcd.sh
. start-external-etcds.sh

rm -f kube.draft
