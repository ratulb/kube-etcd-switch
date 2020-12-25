#!/usr/bin/env bash

. utils.sh

warn "This will erase externally installed etcd instance from this computer!"
read -p "Proceed with the uninstallation? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  prnt "\nAborted etcd uninstall.\n"
  exit 1
fi
data_dir=''
if [ -f /etc/systemd/system/etcd.service ]; then
  data_dir=$(cat /etc/systemd/system/etcd.service | grep data-dir | cut -d'=' -f 2 | cut -d' ' -f 1)
fi

systemctl stop etcd &>/dev/null
systemctl disable etcd &>/dev/null
rm /etc/systemd/system/etcd.service &>/dev/null
rm -rf $data_dir
rm /usr/local/bin/etcd &>/dev/null
rm /usr/local/bin/etcdctl &>/dev/null

systemctl daemon-reload
apt autoremove

prnt "External etcd removed"
