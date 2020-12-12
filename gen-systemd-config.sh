#!/usr/bin/env bash

 . utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 'etcd host' 'etcd ip'" >&2
  exit 1
fi

gendir=./generated
mkdir -p $gendir

token=''
gen_token token

next_data_dir $2

RESTORE_PATH=${RESTORE_PATH:-$NEXT_DATA_DIR}
_initial_cluster_token=${initial_cluster_token:-$token}
_initial_cluster=${initial_cluster:-$1=https:\/\/$2:2380}
cp etcd-systemd-config.template $gendir/$1-etcd.service
cd $gendir
sed -i "s/#etcd-host#/$1/g" $1-etcd.service
sed -i "s/#etcd-ip#/$2/g" $1-etcd.service
sed -i "s|#data-dir#|$RESTORE_PATH|g" $1-etcd.service
sed -i "s|#initial-cluster-token#|${token}|g" $1-etcd.service
if [ -z $mode ]; 
  then
    sed -i "s|#initial-cluster#|${_initial_cluster}|g" $1-etcd.service
fi

cd - &> /dev/null

prnt "generated systemd service config file $gendir/$1-etcd.service"
