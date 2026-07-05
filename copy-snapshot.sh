#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 'snapshot file' 'machine to copy to'"
  return 1
fi
SNAPSHOT=$1
SNAPSHOT_DIR=${SNAPSHOT%/*}

if [ "$this_host_ip" = $2 ]; then
  prnt "Not copying snapshot to localhost."
else
  debug "Creating snapshot directory $SNAPSHOT_DIR at host($2)"
  remote_cmd $2 "sudo mkdir -p $SNAPSHOT_DIR"
  prnt "Copying snapshot $(basename $SNAPSHOT) to host($2)"
  remote_copy $1 $2:/tmp/$(basename $SNAPSHOT)
  remote_cmd $2 "sudo mv /tmp/$(basename $SNAPSHOT) $SNAPSHOT_DIR/"
fi
