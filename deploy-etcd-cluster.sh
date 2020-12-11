#!/usr/bin/env bash
#Generates the certicates for etcd servers using cfssl and ca.crt file from /etc/kubernetes/pki/etcd by default. Any ca can be used used overriding the default - as long apiserver certs can use the ca. 
. utils.sh

if [ ! -f $etcd_ca ] || [ ! -f $etcd_key ]; 
  then
    if [ ! -f $etcd_ca ]; 
      then
        err "$etcd_ca not present!"
      else
        err "$etcd_key not present!"
    fi
    exit 1
fi

prnt "Etcd servers from setup.conf"
for svr in $etcd_servers; do
  prnt $svr
done

prnt  "Please make sure the SSH public key has been copied \
to etcd servers!"

#read -p "Proceed with proceed with the external etcd deployment? " -n 1 -r
#if [[ ! $REPLY =~ ^[Yy]$ ]]
#then
 #   err "\nAborted external etcd deployment.\n"
  #  exit 1
#fi

#backup the current local installation. As long as current local k8s installtion is good we can spin off an etcd cluster based off of it.
next_snapshot
echo 'y'| prompt=no ./embedded-etcd-backup.sh 




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
    prnt "Installing etcd on localhost ($ip)"
    . install-etcd.script
    . make-dirs.script
  else 
    prnt "Installing etcd on host($ip)"
    . execute-script-remote.sh $ip install-etcd.script
    . execute-script-remote.sh $ip make-dirs.script
 fi 
 
done
#gen cert
echo 'y' | ./gen-certs.sh

echo 'y' | ./cluster-etcd-restore.sh

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
    . start-etcd.script
    sleep_few_secs
    systemctl status etcd
  else
    prnt "Copying on to $ip"
    . execute-script-remote.sh $ip make-dirs.script
    . copy-certs-remote.sh $host $ip
    . execute-script-remote.sh $ip start-etcd.script
    sleep_few_secs
    echo "systemctl status etcd" > status.script
    . execute-script-remote.sh $ip status.script
 fi

done

systemctl restart kubelet
sleep 2
prnt "Post etcd restore - checking kube-system pods..."
rm status-report 2> /dev/null

kubectl -n kube-system get pod | tee status-report

status=$(cat status-report |  awk '{if(NR>1)print}' | awk '{print $3}' | sort -u)
i=6
while [ "$i" -gt 0 ] && [[ ! $status =~ "Running" ]] ; do
  sleep $i
  i=$((i-2))
  rm status-report
  kubectl -n kube-system get pod | tee status-report
  status=$(cat status-report |  awk '{if(NR>1)print}' | awk '{print $3}' | sort -u)
done

rm status-report
