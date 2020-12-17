#!/usr/bin/env bash

. utils.sh
. checks/ca-cert-existence.sh
. checks/ssh-access.sh

#Generate certs/systemd/install etcd/create remote dirs/copy certs for etcd servers

. gen-certs.sh

this_host_ip=$(echo $(hostname -i) | cut -d' ' -f1)
this_host=$(hostname)

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}

if  [ "$ip" = $this_host_ip ];
  then
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

done

prnt "Etcd cluster has been setup successfully on $etcd_ips!!!"
