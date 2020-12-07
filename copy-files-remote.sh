#!/usr/bin/env bash 
scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	$(pwd)/generated/$1{-peer.*,-client.*,-server.*} $2:/etc/kubernetes/pki/etcd/

scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	/etc/kubernetes/pki/etcd/ca{.crt,.key} $2:/etc/kubernetes/pki/etcd/

scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $(pwd)/generated/$1-etcd.service $2:/etc/systemd/system/etcd.service

