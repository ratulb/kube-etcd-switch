#!/usr/bin/env bash
if [ ! -f "$1" ]; then
  err "$0 - snapshot($1) does not exists!"
  return 1
fi
