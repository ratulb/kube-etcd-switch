#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 1 ]; then
  #err "Usage: $0 fileName(file name to save state to)"
  err "No name provided - saving as unnamed"
 #return 1
fi

. checks/cluster-state.sh
if [ "$cluster_state" != 'embedded-up' -a "$cluster_state" != 'external-up' ]; then
  err "Cluster state is $cluster_state. Cluster state not saved."
  return 1
fi

when=$(date +%F_%H-%M-%S)
fileName=$1

if [ -z "$fileName" ]; then
  fileName="unnamed-state"
fi

server_ips=$etcd_ips
if [ ! -z "$masters" ]; then
  for mstr in $masters; do
    if [[ ! $etcd_ips =~ "$mstr" ]]; then
      server_ips+=" $mstr"
    fi
  done
fi
server_ips=$(echo $server_ips | xargs)
mkdir -p $kube_vault/system-snaps
mkdir -p $kube_vault/migration-archive
unset skipped_hosts
unset saved_hosts
for ip in $server_ips; do
  if can_access_ip $ip; then
    if [ "$ip" = "$this_host_ip" ]; then
      . archive.script
      mv $kube_vault/system-snap/system-snap.tar.gz $kube_vault/system-snaps/$ip-system-snap.tar.gz
    else
      remote_script $ip archive.script
      remote_copy $ip:/$kube_vault/system-snap/system-snap.tar.gz $kube_vault/system-snaps/$ip-system-snap.tar.gz
      remote_cmd $ip "rm -rf /$kube_vault/system-snap/*"
    fi
    prnt "Saved state for host($ip)"
    if [ -z "$saved_hosts" ]; then
      saved_hosts="$ip"
    else
      saved_hosts+=",$ip"
    fi

  else
    err "Could not access host($ip) - state not saved!"
    if [ -z "$skipped_hosts" ]; then
      skipped_hosts="$ip"
    else
      skipped_hosts+=",$ip"
    fi
  fi
done

cd $kube_vault &>/dev/null
tar cfz $cluster_state#$fileName@$when.tar.gz system-snaps
mv $cluster_state#$fileName@$when.tar.gz migration-archive && rm -rf $kube_vault/system-snaps/* && rm -rf $kube_vault/system-snap/*

archived_file_name="$(basename $cluster_state#$fileName@$when.tar.gz)"
archived_file_name=$(echo $archived_file_name | cut -d'.' -f1)
prnt "Saved state: $archived_file_name for $saved_hosts"
if [ ! -z "$skipped_hosts" ]; then 
  err "Could not access $skipped_hosts - State was not saved for!"
fi
cd - &>/dev/null
