#!/usr/bin/env bash 
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	$(pwd)/generated/$1{-peer.*,.crt,.key} $2:/etc/kubernetes/pki/etcd/

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	/etc/kubernetes/pki/etcd/ca{.crt,.key} $2:/etc/kubernetes/pki/etcd/


scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $(pwd)/generated/$1-etcd.service $2:/etc/systemd/system/etcd.service

