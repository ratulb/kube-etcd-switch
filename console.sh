#!/usr/bin/env bash
. utils.sh
prnt "Entering console - type exit to get out"
bash  -i <<< exec </dev/tty
