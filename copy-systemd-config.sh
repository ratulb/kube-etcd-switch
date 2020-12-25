#!/usr/bin/env bash
. utils.sh

sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
        $gendir/$1-etcd.service $1:/etc/systemd/system/etcd.service

