#!/usr/bin/env bash
#Generates the certicates for etcd servers using cfssl and ca.crt file from /etc/kubernetes/pki/etcd by default. Any ca can be used used overriding the default - as long apiserver certs can use the ca. 
. utils.sh

etcd_ca=/etc/kubernetes/pki/etcd/ca.crt
etcd_key=/etc/kubernetes/pki/etcd/ca.key

if [ ! -f $etcd_ca ] || [ ! -f $etcd_key ]; then
    err "$etcd_ca or/and $etcd_key not present!"
    exit 1
fi

prnt "Etcd servers from setup.conf"
for svr in $etcd_servers; do
  prnt $svr
done

echo  "Please make sure the SSH public key has been copied \
to etcd servers!"

#read -p "Proceed with proceed with the external etcd deployment? " -n 1 -r
#if [[ ! $REPLY =~ ^[Yy]$ ]]
#then
 #   err "\nAborted external etcd deployment.\n"
  #  exit 1
#fi

#backup the current local installation. As long as current local k8s installtion is good we can spin off an etcd cluster based off of it.
deploy_count=0

if [ -d $pre_deploy_backup_loc ]; then
  deploy_count=$(ls $pre_deploy_backup_loc/*.db | wc -l)
fi
((deploy_count++))
ETCD_SNAPSHOT=$pre_deploy_backup_loc/predeploy-snapshot#$deploy_count.db

echo 'y'| prompt=no ./embedded-etcd-backup.sh 

exit 0


this_host=$(hostname)
this_host_ip=$(hostname -i)
cluster=''
gendir=./generated
mkdir -p $gendir
mode=deploy
for svr in $etcd_servers; do
 
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 if [ -z $host ] || [ -z $ip ];
   then
     err "Host or IP address is not valid - can not proceed!"
     exit 1
 fi
 
#Install etcd & setup cert dirs
 if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then 
    prnt "Installing etcd on localhost($ip)"
    . install-etcd.script
    . make-dirs.script
  else 
    prnt "Installing etcd on host($ip)"
    . execute-script-remote.sh $ip install-etcd.script
    . execute-script-remote.sh $ip make-dirs.script
 fi 
 
#systemd file
 . gen-systemd-config.sh $host $ip
 if [ -z $cluster ];
   then
     cluster=$host=https://$ip:2380
   else
     cluster+=,$host=https://$ip:2380
 fi	  
done
sed -i "s|#initial-cluster#|$cluster|g" $gendir/*.service
#gen cert
echo 'y' | ./gen-certs.sh

#distribute files
for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}

  if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then
    prnt "Copying local files on $ip"
    cp $gendir/$host{-peer.*,-client.*,-server.*} /etc/kubernetes/pki/etcd/
    cp $gendir/$host-etcd.service /etc/systemd/system/etcd.service
    #. start-etcd.sh
    #sleep_few_secs
    #. etcd-status.script

  else
    prnt "Copying on to $ip"
    . execute-script-remote.sh $ip make-dirs.script
    . copy-files-remote.sh $host $ip
    #. execute-script-remote.sh $ip start-etcd.sh
    #sleep_few_secs
    #. execute-script-remote.sh $ip etcd-status.script
 fi

done
