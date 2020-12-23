#!/usr/bin/env bash
. utils.sh

last_archived_state $1

echo "$LAST_ARCHIVE"

if [ ! -f "$LAST_ARCHIVE" ]; then
  err "$0 - last archived state does not exists!"
  exit 1
fi
