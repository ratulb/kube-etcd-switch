#!/usr/bin/env bash

. utils.sh

systemctl stop etcd &> /dev/null
systemctl disable etcd &> /dev/null
systemctl daemon-reload
prnt_msg "External etcd stopped"
