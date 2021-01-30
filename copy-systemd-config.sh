#!/usr/bin/env bash
. utils.sh
  remote_copy $gendir/$1-etcd.service $1:/etc/systemd/system/etcd.service

