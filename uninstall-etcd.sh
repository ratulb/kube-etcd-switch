#!/usr/bin/env bash

data_dir=$(cat /etc/systemd/system/etcd.service | grep data-dir | cut -d'=' -f 2 | cut -d' ' -f 1)

systemctl stop etcd
systemctl disable etcd
rm /etc/systemd/system/etcd.service
rm -rf $data_dir
rm /usr/local/bin/etcd
rm /usr/local/bin/etcdctl

systemctl daemon-reload
apt autoremove
