#!/usr/bin/env bash
. utils.sh
host=$1
ip=$2
# Copy via /tmp then sudo mv to final location (target dir is root-owned)
for f in peer.crt peer.key client.crt client.key server.crt server.key; do
  remote_copy $gendir/$host-$f $ip:/tmp/$host-$f
  remote_cmd $ip "sudo mv /tmp/$host-$f /etc/kubernetes/pki/etcd/$host-$f"
done
for f in ca.crt ca.key; do
  remote_copy /etc/kubernetes/pki/etcd/$f $ip:/tmp/$f
  remote_cmd $ip "sudo mv /tmp/$f /etc/kubernetes/pki/etcd/$f"
done
