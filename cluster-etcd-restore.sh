#!/usr/bin/env bash

. utils.sh
  
default_snapshot=
if [ -d "$pre_deploy_backup_loc" ] && [ -f "$pre_deploy_backup_loc"/*.db ]; 
  then 
    default_snapshot=$(ls -t $pre_deploy_backup_loc/*.db | head -n 1)
    prnt "Default snapshot is : $default_snapshot"
  else  
    err "No default snapshot found in $pre_deploy_backup_loc" 
fi


ETCD_SNAPSHOT=${ETCD_SNAPSHOT:- $default_snapshot}
ETCD_SNAPSHOT=/var/lib/etcd-snapshot-first.db
if [ ! -f ${ETCD_SNAPSHOT} ]; then
    err "Snapshot ${ETCD_SNAPSHOT} does not exists!"
    exit 1
fi

install_etcdctl

etcdctl snapshot status ${ETCD_SNAPSHOT} || exit_code=$?

if (( exit_code != 0 )) ;
  then
    err "Status check on $ETCD_SNAPSHOT returned error! Is the snapshot corrupt?"
    exit $exit_code
  else
    prnt "etcd snapshot ${ETCD_SNAPSHOT} looks good!"
fi
rm .suffix
suffix=''
suffix suffix
token=${suffix}

RESTORE_PATH=${RESTORE_PATH:-$default_restore_path}

prnt  "Would restore from $ETCD_SNAPSHOT at $RESTORE_PATH-$token ok? Can change restore locations(from/to) by setting the ETCD_SNAPSHOT/RESTORE_PATH environment variables."
read -p "Proceed with restore? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err "\nAborted backup restore.\n"
    exit 1
fi

prnt "Restoring ${ETCD_SNAPSHOT} on etcd cluster @path: ${RESTORE_PATH}"

this_host=$(hostname)
this_host_ip=$(hostname -i)
initial_cluster=''
etcd_servers=''
mode=restore
SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then
    prnt "Creating directories on localhost($ip)"
    mkdir -p $RESTORE_PATH
  else
    prnt "Creating directories and copying to $ip"
    echo "rm -rf $SNAPSHOT_DIR $RESTORE_PATH; mkdir -p $SNAPSHOT_DIR $RESTORE_PATH > tmp.script"
    . execute-script-remote.sh $ip tmp.script
    . copy-snapshot-remote.sh $ETCD_SNAPSHOT $ip $SNAPSHOT_DIR 
 fi
 if [ -z $initial_cluster ];
   then
     initial_cluster=$host=https://$ip:2380
     etcd_servers=https://$ip:2379
   else
     initial_cluster+=,$host=https://$ip:2380
     etcd_servers+=,https://$ip:2379
 fi
done

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 cp etcd-restore.script $host-etcd-restore.script
 sed -i "s|#ETCD_SNAPSHOT#|$ETCD_SNAPSHOT|g" $host-etcd-restore.script
 sed -i "s|#RESTORE_PATH#|$RESTORE_PATH-$token|g" $host-etcd-restore.script
 sed -i "s|#INITIAL_CLUSTER#|$initial_cluster|g" $host-etcd-restore.script
 sed -i "s|#INITIAL_CLUSTER_TOKEN#|$token|g" $host-etcd-restore.script
 
 if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then
    prnt "Executing etcd restore on localhost($ip)"
    . $host-etcd-restore.script
    mkdir -p $RESTORE_PATH
  else
    prnt "Executing etcd restore on $ip"
   . execute-script-remote.sh $ip $host-etcd-restore.script
 fi
   mv $host-etcd-restore.script ./generated
 #generate systemd files
 . gen-systemd-config.sh $host $ip 

done
sed -i "s|#initial-cluster#|$initial_cluster|g" $gendir/*.service

#TODO copy service files


mv /etc/kubernetes/manifests/kube-apiserver.yaml .
cp kube-apiserver.yaml $SNAPSHOT_DIR/kube-apiserver.yaml.$token
mv /etc/kubernetes/manifests/etcd.yaml $SNAPSHOT_DIR/etcd.yaml.$token
cp kube-apiserver.yaml kube.draft
sed -i "s|apiserver-etcd-client|$(hostname)-client|g" kube.draft
cp /etc/kubernetes/pki/etcd/$(hostname)-client.* /etc/kubernetes/pki/
sed -i "s|https://127.0.0.1:2379|$etcd_servers|g" kube.draft
mv kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml

prnt "Snapshot restored"

