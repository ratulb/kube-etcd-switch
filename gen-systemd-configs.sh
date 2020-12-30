#!/usr/bin/env bash
. utils.sh

rm -f ${gendir}/*.service
token=''
gen_token token
etcd_initial_cluster

cluster_token=${initial_cluster_token:-$token}
initial_cluster=${ETCD_INITIAL_CLUSTER}

for svr in $etcd_servers; do

  pair=(${svr//:/ })
  host=${pair[0]}
  ip=${pair[1]}
  next_data_dir $ip
  restore_path=${RESTORE_PATH:-$NEXT_DATA_DIR}
  cp etcd-systemd-config.template $gendir/$ip-etcd.service

  cd $gendir

  sed -i "s/#etcd-host#/$host/g" $ip-etcd.service
  sed -i "s/#etcd-ip#/$ip/g" $ip-etcd.service
  sed -i "s|#data-dir#|$restore_path|g" $ip-etcd.service
  sed -i "s|#initial-cluster-token#|${cluster_token}|g" $ip-etcd.service
  sed -i "s|#initial-cluster#|${initial_cluster}|g" $ip-etcd.service

  cd - &> /dev/null

  debug "generated systemd service config file $gendir/$ip-etcd.service"

done
