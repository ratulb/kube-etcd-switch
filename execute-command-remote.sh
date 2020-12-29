#!/usr/bin/env bash 
#Execute remote command
. utils.sh

remote_host=$1
shift
args="$@"
prnt "Executing commmand on $remote_host"
sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $remote_host $args
