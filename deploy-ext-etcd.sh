#!/usr/bin/env bash
#Generates the certicates for etcd servers using cfssl and ca.crt file from /etc/kubernetes/pki/etcd by default. Any ca can be used used overriding the default - as long apiserver certs can use the ca. 
. utils.sh

etcd_ca=/etc/kubernetes/pki/etcd/ca.crt
etcd_key=/etc/kubernetes/pki/etcd/ca.key

if [ ! -f $etcd_ca ] || [ ! -f $etcd_key ]; then
    err_msg "$etcd_ca or/and $etcd_key not present!"
    exit 1
fi

prnt_msg "Etcd servers from setup.conf"
for svr in $etcd_servers; do
  prnt_msg $svr
done

echo  "Please make sure the SSH public key has been copied \
to etcd servers!"

#read -p "Proceed with proceed with the external etcd deployment? " -n 1 -r
#if [[ ! $REPLY =~ ^[Yy]$ ]]
#then
 #   err_msg "\nAborted external etcd deployment.\n"
  #  exit 1
#fi

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
     err_msg "Host or IP address is not valid - can not proceed!"
     exit 1
 fi
 
#Install etcd & setup cert dirs
 if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then 
    prnt_msg "Installing etcd on localhost($ip)"
    . install-etcd.sh
    . make-dirs.sh
  else 
    prnt_msg "Installing etcd on host($ip)"
    . execute-file-remote.sh $ip install-etcd.sh
    . execute-file-remote.sh $ip make-dirs.sh
 fi 
 
#systemd file
 . gen-systemd.sh $host $ip
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
    prnt_msg "Copying local files on $ip"
    cp $gendir/$host{-peer.*,-client.*,-server.*} /etc/kubernetes/pki/etcd/
    cp $gendir/$host-etcd.service /etc/systemd/system/etcd.service
    #mv /etc/kubernetes/manifests/etcd.yaml .etcd.yaml.copied
    #mv /etc/kubernetes/manifests/kube-apiserver.yaml .kube-apiserver.yaml.copied
    #cp .kube-apiserver.yaml.copied kube-apiserver-external-etcd.yaml
    . start-etcd.sh
    sleep_few_secs
    . etcd-status.cmd

  else
    prnt_msg "Copying on to $ip"
    . execute-file-remote.sh $ip make-dirs.sh
    . copy-files.sh $host $ip
    . execute-file-remote.sh $ip start-etcd.sh
    sleep_few_secs
    . execute-file-remote.sh $ip etcd-status.cmd
 fi

done
