#!/usr/bin/env bash
. utils.sh

last_snapshot $1

if [ ! -f "$LAST_SNAPSHOT" ]; then
  last_snapshot $2
fi

export ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$LAST_SNAPSHOT}

