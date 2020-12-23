#!/usr/bin/env bash
. utils.sh
if [ "$this_host_ip" = $master_ip ]; then
  mv /etc/kubernetes/manifests/kube-apiserver.yaml $kube_vault/kube-apiserver.yaml
else
  sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml $kube_vault/kube-apiserver.yaml

  if [ -f $kube_vault/paused-kube-apiserver.yaml ]; then
    sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $master_ip rm -f /etc/kubernetes/manifests/kube-apiserver.yaml
  fi

fi
