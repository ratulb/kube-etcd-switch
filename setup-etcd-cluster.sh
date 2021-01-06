#!/usr/bin/env bash
. utils.sh
. checks/ca-cert-existence.sh

servers=$etcd_servers
if [ "$#" -ge 0 ]; then
  servers=$@
fi

. checks/ssh-access.sh $servers

#Generate certs/systemd/install etcd/create remote dirs/copy certs for etcd servers
. gen-certs.sh $servers

for host_and_ip in $servers; do
  host=$(echo $host_and_ip | cut -d':' -f1)
  ip=$(echo $host_and_ip | cut -d':' -f2)

  if [ "$ip" = $this_host_ip ]; then
    prnt "Installing etcd/creating default directories on localhost ($ip)"
    . install-etcd.script
    . prepare-etcd-dirs.script $default_backup_loc $default_restore_path
    prnt "Copying certs on local machine $ip"
    cp $gendir/$host{-peer.*,-client.*,-server.*} /etc/kubernetes/pki/etcd/
  else
    prnt "Installing etcd/creating default directories on host($ip)"
    . execute-script-remote.sh $ip install-etcd.script
    dress_up_script prepare-etcd-dirs.script
    . execute-script-remote.sh $ip prepare-etcd-dirs.script.tmp
    prnt "Copying certs to remote machine $ip"
    . copy-certs.sh $host $ip
  fi
  rm prepare-etcd-dirs.script.tmp
done

prnt "Etcd cluster has been setup successfully on servers."
