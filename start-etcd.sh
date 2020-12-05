#!/usr/bin/env bash 

systemctl daemon-reload
systemctl enable etcd
systemctl restart etcd
systemctl status etcd
