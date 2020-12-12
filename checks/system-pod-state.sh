#!/usr/bin/env bash

echo "Checking kube-system pods..."
rm status-report 2> /dev/null
kubectl -n kube-system get pod | tee status-report
status=$(cat status-report |  awk '{if(NR>1)print}' | awk '{print $3}' | sort -u)
i=$1
secs=$2
while [ "$i" -gt 0 ] && [[ ! $status =~ "Running" ]] ; do
  sleep $secs
  #TODO
  #i=$((i-1))
  rm status-report
  kubectl -n kube-system get pod | tee status-report
  status=$(cat status-report |  awk '{if(NR>1)print}' | awk '{print $3}' | sort -u)
done
rm status-report

