#!/usr/bin/env bash
. utils.sh
if [ "$#" -ne 2 ]; then
  err "Usage: $0 'admitted node ip' 'cluster[embedded|external]'"
  return 1
fi
node_ip=$1
cluster=$2
unset ENDPOINTS
if [[ "$cluster" = 'external' ]] && ext_etcd_endpoints; then
  ENDPOINTS=$EXTERNAL_ETCD_ENDPOINTS
elif [[ "$cluster" = 'embedded' ]] && emd_etcd_endpoints; then
  ENDPOINTS=$EMBEDDED_ETCD_ENDPOINTS
else
  err "No cluster endpoint(s) for $cluster. Node($node_ip) not removed"
  return 1
fi
prnt "Removing node($node_ip) from $cluster cluster"
etcd_cmd --endpoints=$ENDPOINTS member list &>/tmp/rm_ep_probe_resp.txt

if [ ! -z "$debug" ]; then
  cat /tmp/rm_ep_probe_resp.txt
fi

cat /tmp/rm_ep_probe_resp.txt | grep 'connection refused|deadline exceeded' | grep https://$node_ip:2380
[[ "$?" -eq 0 ]] && err "Removing node $node_ip - cluster is down or not setup" && return 1

cat /tmp/rm_ep_probe_resp.txt | grep -E 'started|unstarted' | grep -q https://$node_ip:2380
if [ "$?" -eq 1 ]; then
  err "Removing node($node_ip) - Node not part of $cluster cluster"
  return 1
fi
[[ "$?" -eq 1 ]] && err "Removing node($node_ip) - Node not found" && return 1

cat /tmp/rm_ep_probe_resp.txt | grep -q -E 'started|unstarted' | grep https://$node_ip:2380
[[ "$?" -eq 0 ]] && prnt "Removing node($node_ip) from $cluster cluster"

member_id=$(cat /tmp/rm_ep_probe_resp.txt | grep $node_ip | cut -d ',' -f1 | xargs)
warn "Removing member: $member_id from $cluster cluster"

etcd_cmd --endpoints=$ENDPOINTS member remove $member_id &>/tmp/member-remove-resp.txt

cat /tmp/member-remove-resp.txt | grep -q -E 'connection refused|deadline exceeded'
[[ "$?" -eq 0 ]] && err "Removing node($node_ip) - could not contact $node_ip" && return 1

cat /tmp/member-remove-resp.txt | grep "Member $member_id removed from"
([[ "$?" -eq 0 ]] && prnt "Removing node($node_ip) - node has been removed") || (err "Failed to remove node($node_ip)" && return 1)

cat /tmp/member-remove-resp.txt | grep -q 're-configuration failed due to not enough started members'
[[ "$?" -eq 0 ]] && err "Removing node($node_ip) - could not remove node due to lack of quorum" && return 1
