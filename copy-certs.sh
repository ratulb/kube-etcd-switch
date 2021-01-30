#!/usr/bin/env bash
. utils.sh
remote_copy $gendir/$1-peer.crt $2:/etc/kubernetes/pki/etcd/
remote_copy $gendir/$1-peer.key $2:/etc/kubernetes/pki/etcd/
remote_copy $gendir/$1-client.crt $2:/etc/kubernetes/pki/etcd/
remote_copy $gendir/$1-client.key $2:/etc/kubernetes/pki/etcd/
remote_copy $gendir/$1-server.crt $2:/etc/kubernetes/pki/etcd/
remote_copy $gendir/$1-server.key $2:/etc/kubernetes/pki/etcd/
remote_copy /etc/kubernetes/pki/etcd/ca.crt $2:/etc/kubernetes/pki/etcd/
remote_copy /etc/kubernetes/pki/etcd/ca.key $2:/etc/kubernetes/pki/etcd/
