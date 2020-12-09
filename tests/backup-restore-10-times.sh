#!/usr/bin/env bash 
cd ..
i=10
while [ "$i" -gt 0 ]; do
  echo 'y' | ./embedded-etcd-backup.sh 
  sleep 3
  i=$((i-1))
  echo 'y' | ./embedded-etcd-restore.sh
done
cd -
