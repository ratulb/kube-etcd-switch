#!/usr/bin/env bash
status=$(kubectl -n kube-system get pod | grep etcd | awk '{print $3}')
if [ ! "$status" = "Running" ];
  then
    warn "etcd pod does not seem to be up"
fi
