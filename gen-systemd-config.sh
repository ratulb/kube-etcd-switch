#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 3 ]; then
  err "Usage: $0 'etcd host' 'etcd ip' 'initial cluster url'" >&2
  exit 1
fi
host=$1
ip=$2
cluster=$3
prnt "Node becoming member of : $cluster"
next_data_dir $ip
restore_path=$NEXT_DATA_DIR

cp etcd-systemd-config.template $gendir/$ip-etcd.service

cd $gendir

sed -i "s/#etcd-host#/$host/g" $ip-etcd.service
sed -i "s/#etcd-ip#/$ip/g" $ip-etcd.service
sed -i "s|#data-dir#|$restore_path|g" $ip-etcd.service
sed -i "s|token=#initial-cluster-token#|state=existing|g" $ip-etcd.service
sed -i "s|#initial-cluster#|$cluster|g" $ip-etcd.service

cd - &> /dev/null

prnt "generated systemd service config file $gendir/$ip-etcd.service"
