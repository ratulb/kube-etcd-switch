#!/usr/bin/env bash 
cd ..
i=10
#TODO
while [ "$i" -gt 0 ]; do
  #echo 'y' | ./backup-embedded-etcd.sh 
  ./destructive-script.sh
  sleep 10
  i=$((i-1))
  echo 'y' | ./restore-embedded-etcd.sh
done
cd -
