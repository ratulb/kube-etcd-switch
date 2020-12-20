#!/usr/bin/env bash
. utils.sh

cp $HOME/.kube_vault/kube-apiserver.yaml kube.draft

api_server_etcd_url

current_url=https://127.0.0.1:2379
cluster_etcd_url=$API_SERVER_ETCD_URL

sed -i "s|$current_url|$cluster_etcd_url|g" kube.draft
token=''
gen_token token

if [ "$this_host_ip" = $master_ip ]; then
  mv /etc/kubernetes/manifests/etcd.yaml $HOME/.kube_vault/$token-etcd.yaml
  mv kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
else
  sudo -u $usr ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip "mv /etc/kubernetes/manifests/etcd.yaml $HOME/.kube_vault/$token-etcd.yaml"
  sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    $(pwd)/kube.draft $master_ip:/etc/systemd/system/kube-apiserver.yaml

fi

for ip in $etcd_ips; do
  if [ "$this_host_ip" = $ip ]; then
    . start-etcd.script
  else
    . execute-script-remote.sh $ip start-etcd.script
  fi
done

prnt "Started cluster etcd servers!"
