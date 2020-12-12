#!/usr/bin/env bash 
. utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 'snapshot file' 'machine to copy to'" >&2
  exit 1
fi
this_host_ip=$(hostname -i)
if [ "$this_host_ip" = $2 ]; then
  echo "I am the source($2) - not copying to myself($1)"
  exit 0 
fi
SNAPSHOT=$1
SNAPSHOT_DIR=${SNAPSHOT%/*}
sudo -u $usr ssh -o "StrictHostKeyChecking no" \
	-o "ConnectTimeout=5" $2 "mkdir -p $SNAPSHOT_DIR"
sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null $1 $2:$SNAPSHOT_DIR


