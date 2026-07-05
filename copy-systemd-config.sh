#!/usr/bin/env bash
. utils.sh
remote_copy $gendir/$1-etcd.service $1:/tmp/etcd.service
remote_cmd $1 "sudo mv /tmp/etcd.service /etc/systemd/system/etcd.service"
