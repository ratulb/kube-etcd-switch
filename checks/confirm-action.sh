#!/usr/bin/env bash

action=$1
abort_msg=$2

read -p "$action?" -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  err "\nAborted $abort_msg.\n"
  exit 1
fi
