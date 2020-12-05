#!/usr/bin/env bash

 . utils.sh

if [ "$#" -ne 2 ]; then
  err_msg "Usage: $0 etcd-host etcd-ip" >&2
  exit 1
fi

gendir=./generated
mkdir -p $gendir

cp etcd-systemd.template $gendir/$1-etcd.service
cd $gendir
sed -i "s/#etcd-host#/$1/g" $1-etcd.service
sed -i "s/#etcd-ip#/$2/g" $1-etcd.service
cd -


