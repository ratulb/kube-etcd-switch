#!/usr/bin/env bash
. utils.sh
remote_copy $gendir/$1{-peer.*,-client.*,-server.*} $2:/etc/kubernetes/pki/etcd/
if [ "$?" -eq 0 ] || err "Failed to copy certs" && return 1
remote_copy /etc/kubernetes/pki/etcd/ca{.crt,.key} $2:/etc/kubernetes/pki/etcd/
