#!/usr/bin/env bash
. utils.sh
warn "Entering console - type exit to get out"
bash  -i <<< exec </dev/tty
