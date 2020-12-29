#!/usr/bin/env bash
. utils.sh

if [ "$#" -ne 1 ]; then
  err "Usage: $0 fileName(file name to save state to)"
  exit 1
fi

debug=yes . checks/cluster-state.sh
if [ "$cluster_state" != 'embedded-up' -a "$cluster_state" != 'external-up' ]; then
  err "Cluster state is $cluster_state. Declining request."
  exit 1
fi

when=$(date +%F_%H-%M-%S)
fileName=$1

server_ips="$etcd_ips"
if [[ ! $etcd_ips =~ "$master_ip" ]]; then
  server_ips+=" $master_ip"
fi

mkdir -p $kube_vault/system-snaps
mkdir -p $kube_vault/migration-archive
for ip in $server_ips; do
  if [ "$ip" = "$this_host_ip" ]; then
    . archive.script
    mv $kube_vault/system-snap/system-snap.tar.gz $kube_vault/system-snaps/$ip-system-snap.tar.gz
  else
    . execute-script-remote.sh $ip archive.script
    sudo -u $usr scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      $ip:/$kube_vault/system-snap/system-snap.tar.gz $kube_vault/system-snaps/$ip-system-snap.tar.gz
    sudo -u $usr ssh -o "StrictHostKeyChecking no" -o "ConnectTimeout=5" $ip "rm -rf /$kube_vault/system-snap/*"
  fi
done

cd $kube_vault
tar cfz $cluster_state#$fileName@$when.tar.gz system-snaps
mv $cluster_state#$fileName@$when.tar.gz migration-archive && rm -rf $kube_vault/system-snaps/* && rm -rf $kube_vault/system-snap/*

archived_file_name="$(basename $cluster_state#$fileName@$when.tar.gz)"
archived_file_name=$(echo $archived_file_name | cut -d'.' -f1)
prnt "Saved state: $archived_file_name"
cd - &>/dev/null

