#!/usr/bin/env bash
. utils.sh
api_server_etcd_url
_host_and_ip=$1
_ip=$(echo $_host_and_ip | cut -d':' -f2)
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
  --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
  --endpoints=$API_SERVER_ETCD_URL member list &>/tmp/rm_ep_probe_resp.txt

cat /tmp/rm_ep_probe_resp.txt

cat /tmp/rm_ep_probe_resp.txt | grep 'connection refused|deadline exceeded' | grep https://$_ip:2380
[[ "$?" -eq 0 ]] && err "Removing node $_ip - cluster is down or not setup" && return 1

cat /tmp/rm_ep_probe_resp.txt | grep -E 'started|unstarted' | grep https://$_ip:2380
if [ "$?" -eq 1 ]; then
  err "Removing node $_ip - not found"
  prune_etcd_server_list $_host_and_ip
  . synch-etcd-endpoints.sh
  return 1
fi

[[ "$?" -eq 1 ]] && err "Removing node $_ip - not found" && return 1

cat /tmp/rm_ep_probe_resp.txt | grep -E 'started|unstarted' | grep https://$_ip:2380
[[ "$?" -eq 0 ]] && err "Removing node $_ip"

member_id=$(cat /tmp/rm_ep_probe_resp.txt | grep $_ip | cut -d ',' -f1 | xargs)
warn "Removing member: $member_id"

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=$kube_api_etcd_client_cert --key=$kube_api_etcd_client_key --endpoints=$API_SERVER_ETCD_URL member remove $member_id &>/tmp/member-remove-resp.txt

cat /tmp/member-remove-resp.txt | grep -E 'connection refused|deadline exceeded'
[[ "$?" -eq 0 ]] && err "Removing node $_ip - could not contact $_ip" && return 1

cat /tmp/member-remove-resp.txt | grep "Member $member_id removed from"
( [[ "$?" -eq 0 ]] && prnt "Removing node $_ip - node has been removed" ) || ( err "Failed to remove node $_ip" && return 1 )

cat /tmp/member-remove-resp.txt | grep 're-configuration failed due to not enough started members'
[[ "$?" -eq 0 ]] && err "Removing node $_ip - could not remove node due to lack of quorum" && return 1

. stop-external-etcds.sh "" $_ip
