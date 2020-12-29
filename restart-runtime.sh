#!/usr/bin/env bash
. utils.sh

args="$@"
nodes=$(kubectl get nodes -o wide --no-headers | awk '{print $6}' | tr '\n' ' ')

if [ -z "$nodes" -a "$#" -eq 0 ]; then
  err "Cluster node probe failed - Can not proceed."
else
    if [ -z "$nodes" -a \( "$#" -gt 0 \) ]; then
    nodes="$@"
  fi
  for node in $nodes; do
    if [ "$node" = "$this_host_ip" ]; then
      prnt "Restarting kube runtime on $node"
      sudo systemctl restart docker
      sleep_few_secs
      sudo systemctl restart kubelet
    else
      prnt "Restarting kube runtime on $node"
      sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $node systemctl restart docker
      sleep_few_secs
      sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $node systemctl restart kubelet
    fi
  done
  prnt "Restarted runtime on $nodes"
fi
