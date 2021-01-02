#!/usr/bin/env bash
. utils.sh
. checks/ca-cert-existence.sh
host=$1
ip=$2
if ! can_access_ip $ip; then
  err "Can not access server($ip). Not proceeding with etcd setup"
  return 1
fi
#Generate certs/systemd/install etcd/create remote dirs/copy certs for single etcd node
. gen-cert.sh $host $ip

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

prnt "Etcd node $host($ip) was successfully added."
