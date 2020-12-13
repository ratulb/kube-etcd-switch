#!/usr/bin/env bash
. utils.sh

gendir=./generated
mkdir -p ${gendir}
rm -f ${gendir}/*.service
token=''
gen_token token
next_data_dir $ip
etcd_initial_cluster

restore_path=${RESTORE_PATH:-$NEXT_DATA_DIR}
cluster_token=${initial_cluster_token:-$token}
initial_cluster=${ETCD_INITIAL_CLUSTER}

for svr in $etcd_servers; do

  pair=(${svr//:/ })
  host=${pair[0]}
  ip=${pair[1]}

  cp etcd-systemd-config.template $gendir/$host-etcd.service

  cd $gendir

  sed -i "s/#etcd-host#/$host/g" $host-etcd.service
  sed -i "s/#etcd-ip#/$ip/g" $host-etcd.service
  sed -i "s|#data-dir#|$restore_path|g" $host-etcd.service
  sed -i "s|#initial-cluster-token#|${cluster_token}|g" $host-etcd.service
  sed -i "s|#initial-cluster#|${initial_cluster}|g" $host-etcd.service

  cd - &> /dev/null

  prnt "generated systemd service config file $gendir/$host-etcd.service"

done
