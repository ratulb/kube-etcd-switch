#!/usr/bin/env bash

 . utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 etcd-host etcd-ip" >&2
  exit 1
fi

gendir=./generated
mkdir -p $gendir
suffix=''
suffix suffix
token=${suffix}
data_dir=${data_dir:-$default_restore_path-$token}
initial_cluster_token=${initial_cluster_token:-$token}
initial_cluster=${initial_cluster:-$1=https:\/\/$2:2380}
cp etcd-systemd-config.template $gendir/$1-etcd.service
cd $gendir
sed -i "s/#etcd-host#/$1/g" $1-etcd.service
sed -i "s/#etcd-ip#/$2/g" $1-etcd.service
sed -i "s|#data-dir#|${data_dir}|g" $1-etcd.service
sed -i "s|#initial-cluster-token#|${initial_cluster_token}|g" $1-etcd.service
if [ -z $mode ]; 
  then
    sed -i "s|#initial-cluster#|${initial_cluster}|g" $1-etcd.service
fi

cd - &> /dev/null
