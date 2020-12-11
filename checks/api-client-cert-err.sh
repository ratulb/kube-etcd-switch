#!/usr/bin/env bash
if [ ! -f "$kube_api_client_cert" ] || [ ! -f "$kube_api_client_key" ]; then
  err "API client cert/key missing!"
  exit 1
fi

