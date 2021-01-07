#!/usr/bin/env bash
. utils.sh

probe_endpoints
ip=$1
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
  --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
  --endpoints=$PROBE_ENDPOINTS member list &>/tmp/rm_ep_probe_resp.txt

cat /tmp/rm_ep_probe_resp.txt
echo "IP is $ip"
cat /tmp/rm_ep_probe_resp.txt | grep 'connection refused|deadline exceeded' | grep https://$ip:2380
[[ "$?" -eq 0 ]] && err "Removing node $ip - cluster is down or not setup" && return 1

cat /tmp/rm_ep_probe_resp.txt | grep -E 'started|unstarted' | grep https://$ip:2380
[[ "$?" -eq 1 ]] && err "Removing node $ip - not found" && return 1

cat /tmp/rm_ep_probe_resp.txt | grep -E 'started|unstarted' | grep https://$ip:2380
[[ "$?" -eq 0 ]] && err "Removing node $ip"

member_id=$(cat /tmp/rm_ep_probe_resp.txt | grep $ip | cut -d ',' -f1 | xargs)
warn "Removing member: $member_id"

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=$kube_api_etcd_client_cert --key=$kube_api_etcd_client_key --endpoints=https://10.148.15.227:2379,https://10.148.15.228:2379 member remove $member_id &>/tmp/member-remove-resp.txt

cat /tmp/member-remove-resp.txt | grep -E 'connection refused|deadline exceeded'
[[ "$?" -eq 0 ]] && err "Removing node $ip - could not contact $ip" && return 1

cat /tmp/member-remove-resp.txt | grep "Member $member_id removed from"
( [[ "$?" -eq 0 ]] && prnt "Removing node $ip - node has been removed" ) || ( err "Failed to remove node $ip" && return 1 )

cat /tmp/member-remove-resp.txt | grep 're-configuration failed due to not enough started members'
[[ "$?" -eq 0 ]] && err "Removing node $ip - could not remove node due to lack of quorum" && return 1

. stop-external-etcds.sh "" $ip
