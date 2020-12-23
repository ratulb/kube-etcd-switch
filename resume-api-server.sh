#!/usr/bin/env bash
. utils.sh

if [ -f $kube_vault/kube-apiserver.yaml ]; then

  if [ "$this_host_ip" = $master_ip ]; then
    cp $kube_vault/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
  else
    sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      $kube_vault/kube-apiserver.yaml $master_ip:/etc/kubernetes/manifests/kube-apiserver.yaml
  fi

else
  err "kube-apiserver.yaml not found to restore!"
fi
