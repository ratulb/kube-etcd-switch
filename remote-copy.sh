#!/usr/bin/env bash 
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1:{pwd}/generated/$2 /etc/kubernetes/pki/etcd/

