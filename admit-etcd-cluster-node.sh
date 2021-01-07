#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 2 ]; then
  err "Usage: $0 'hostname' 'host ip address'"
  exit 1
fi
probe_endpoints
host=$1
ip=$2
host_and_ip=$1:$2
prnt "host: $host and ip is $ip"

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
  --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
  --endpoints=$PROBE_ENDPOINTS member list &>/tmp/add_ep_probe_resp.txt

cat /tmp/add_ep_probe_resp.txt | grep -q -E 'connection refused|deadline exceeded'
[[ "$?" -eq 0 ]] && err "Connection error" && return 1

cat /tmp/add_ep_probe_resp.txt | grep "$ip" | grep 'unstarted'
[[ "$?" -eq 0 ]] && err "Node already added but not started" && return 1

cat /tmp/add_ep_probe_resp.txt | grep "$ip" | grep 'started'
[[ "$?" -eq 0 ]] && err "Node already added" && return 1

prnt "Adding node($host) with ip($ip) to etcd cluster"

ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=$kube_api_etcd_client_cert --key=$kube_api_etcd_client_key \
  --endpoints=$PROBE_ENDPOINTS member add $host \
  --peer-urls=https://$ip:2380 >/tmp/member_add_resp.txt 2>&1

cat /tmp/member_add_resp.txt | grep 'unhealthy cluster'
[[ "$?" -eq 0 ]] && err "Cluster is unhealthy - previously added node may not have been started yet" && return 1

cat /tmp/member_add_resp.txt | grep -q 'ETCD_NAME'
[[ "$?" -eq 0 ]] && prnt "Node has been added to the cluster"
initial_cluster_url=$(cat /tmp/member_add_resp.txt | grep 'ETCD_INITIAL_CLUSTER'| head -n 1 | cut -d '"' -f2)
. gen-systemd-config.sh $host $ip $initial_cluster_url
if can_access_ip $ip; then
  if [ "$this_host_ip" = $ip ]; then
    cp $gendir/$ip-etcd.service /etc/systemd/system/etcd.service
  else
    . copy-systemd-config.sh $ip
  fi
  prnt "Starting etcd for admitted etcd($host_and_ip)"
  . start-external-etcds.sh $ip || return 1
else
  err "Could not access host($ip) - systemd config not copied and server not started"
  return 1
fi
