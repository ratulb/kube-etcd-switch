#!/usr/bin/env bash 
scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	$1 $2:$3


