#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 'etcd data directory(empty)' 'intial cluster token'"
  exit 1
fi
data_dir=$1
token=$2
machine_ip=$3

cat $kube_vault/etcd.yaml.encoded | base64 -d >  etcd.draft
old_data_dir=$(cat etcd.draft | grep "\-\-data-dir=")
old_data_dir=${old_data_dir:17}
sed -i "s|$old_data_dir|$data_dir|g" etcd.draft

#initial-cluster-token
sed -i '/initial-cluster-token/d' etcd.draft
sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=$token" etcd.draft

prnt "Modified etcd.yaml that would be applied: "
prnt "*******************************************"
cat etcd.draft
prnt "*******************************************"

read -p "Go ahead with final restore step? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
   err "\nAborted backup restore.\n"
   rm -f etcd.draft
   exit 1
fi

