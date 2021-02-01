#!/usr/bin/env bash
. utils.sh

if command_exists kubectl; then
prnt "Checking kube-system pods..."
rm status-report 2>/dev/null
kubectl -n kube-system get pod | tee status-report
status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " " | xargs)
i=$1
secs=$2
while [ "$i" > 0 ] && [[ ! "$status" = "Running" ]]; do
  sleep $secs
  #TODO - Uncomment the following to relent after tring after $1 times
  #i=$((i-1))
  rm status-report
  kubectl -n kube-system get pod | tee status-report
  status=$(cat status-report | awk '{if(NR>1)print}' | awk '{print $3}' | sort -u | tr "\n" " "| xargs)
done
rm -f status-report
echo ""
else
 err "kubectl is not found - Has the system been initialized?"
 return 1
fi
