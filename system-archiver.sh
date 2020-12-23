#!/usr/bin/env bash
. utils.sh

debug=yes
. checks/cluster-state.sh
state_desc=${state_desc:-$1}

token=''
gen_token token

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

cd $kube_vault && echo $state_desc > system-snaps/state.txt
tar cfz $cluster_state#$token.tar.gz system-snaps
mv $cluster_state#$token.tar.gz migration-archive && rm -rf $kube_vault/system-snaps/* && rm -rf $kube_vault/system-snap/*


