#!/usr/bin/env bash 
#Execute remote command
. utils.sh
prnt_msg "Executing on $1"
sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $1 < $2
