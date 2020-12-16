#!/usr/bin/env bash
. utils.sh
. checks/ca-cert-existence.sh
. checks/ssh-access.sh

#take back up of existing embedded etcd
#echo 'y' | . backup-embedded-etcd.sh

#Generate certs/systemd/install etcd/create remote dirs/copy files for etcd servers

. gen-certs.sh
. gen-systemd-configs.sh 

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
    #cp $gendir/$host-etcd.service /etc/systemd/system/etcd.service

  else
    prnt "Installing etcd/creating default directories on host($ip)"

    . execute-script-remote.sh $ip install-etcd.script
    dress_up_script prepare-etcd-dirs.script
    . execute-script-remote.sh $ip prepare-etcd-dirs.sh.tmp 

    prnt "Copying certs and systemd files on remotemachine $ip"
    . copy-certs.sh $host $ip
 fi 

done

prnt "Etcd cluster has been setup successfully on $etcd_ips!!!"
