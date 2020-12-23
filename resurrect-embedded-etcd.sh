#!/usr/bin/env bash

. pause-api-server.sh
. stop-etcd-cluster.sh
. resume-embedded-etcd.sh
. checks/endpoint-liveness.sh 5 3
. resume-api-server.sh
. checks/system-pod-state.sh 5 3
