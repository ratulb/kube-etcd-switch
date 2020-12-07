#!/usr/bin/env bash 

cp /etc/kubernetes/pki/etcd/ca.crt /usr/local/share/ca-certificates/
update-ca-certificates

systemctl daemon-reload
systemctl enable etcd
systemctl restart etcd
systemctl status etcd
