#!/usr/bin/env bash
. utils.sh

token=''
gen_token token

sudo -u $usr ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
	$1 "mv /etc/systemd/system/etcd.service $HOME/.kube_vault/$token-etcd.service" 

sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
        $(pwd)/generated/$1-etcd.service $1:/etc/systemd/system/etcd.service

