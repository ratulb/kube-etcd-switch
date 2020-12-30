#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 'snapshot file' 'machine to copy to'" >&2
  exit 1
fi
SNAPSHOT=$1
SNAPSHOT_DIR=${SNAPSHOT%/*}

if [ "$this_host_ip" = $2 ]; then
  prnt "Not copying snapshot to localhost."
else
  debug "Creating snapshot directory $SNAPSHOT_DIR @host($2)"
  . execute-command-remote.sh $2 "mkdir -p $SNAPSHOT_DIR"
  prnt "Copying snapshot $(basename $SNAPSHOT) to host($2)"
  sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null $1 $2:$SNAPSHOT_DIR
fi
