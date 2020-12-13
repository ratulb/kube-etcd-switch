#!/usr/bin/env bash
if [ ! -f "$kube_api_etcd_client_cert" ] || [ ! -f "$kube_api_etcd_client_key" ]; then
  err "API client cert/key missing!"
  exit 1
fi
