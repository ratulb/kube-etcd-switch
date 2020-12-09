#!/usr/bin/env bash

. utils.sh
  
last_snapshot=''
if [ -d "$default_backup_loc" ]; 
  then 
    count=$(find $default_backup_loc -maxdepth 1 -type f -name "*.db" | wc -l)
    if [ $count > 0]; then
      last_snapshot=$(ls -t $default_backup_loc/*.db | head -n 1)
      last_snapshot=$(readlink -f $last_snapshot)
      prnt "Last snapshot is : $last_snapshot"
    fi
  else  
    err "No snapshot found in $default_backup_loc" 
fi

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-$last_snapshot}

if [ ! -f $ETCD_SNAPSHOT ]; then
  err "No snapshot $ETCD_SNAPSHOT does not exist!"
  exit 1
fi

install_etcdctl

etcdctl snapshot status ${ETCD_SNAPSHOT} || exit_code=$?

if (( exit_code != 0 )) ;
  then
    err "Status check on $ETCD_SNAPSHOT returned error! Is the snapshot corrupt?"
    exit $exit_code
  else
    prnt "etcd snapshot $ETCD_SNAPSHOT status checked passed!"
fi

count=0
if [ -d $data_dir ]; then
  count=$(find $data_dir/* -maxdepth 0 -type d | wc -l)
fi
((count++))
RESTORE_PATH=${RESTORE_PATH:-$data_dir/restore#$count}

export $RESTORE_PATH

prnt  "Restoring ${ETCD_SNAPSHOT} on etcd cluster @path: ${RESTORE_PATH}. Can change restore locations(from/to) by setting the ETCD_SNAPSHOT/RESTORE_PATH environment variables."
read -p "Proceed with restore? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err "\nAborted backup restore.\n"
    exit 1
fi

this_host=$(hostname)
this_host_ip=$(hostname -i)
initial_cluster=''
etcd_servers=''
SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
RESTORE_PATH_PARENT="$(dirname "$RESTORE_PATH")"

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then
    prnt "Creating restore path $RESTORE_PATH_PARENT on localhost($ip)"
    rm -rf $RESTORE_PATH
    mkdir -p $RESTORE_PATH_PARENT
  else
    prnt "Creating restore path $RESTORE_PATH_PARENT and copying snapshot to $ip"
    echo "rm -rf $RESTORE_PATH; mkdir -p $SNAPSHOT_DIR $RESTORE_PATH_PARENT" > tmp.script
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

rm .token
token=''
gen_token token

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 cp etcd-restore.script $host-etcd-restore.script
 sed -i "s|#ETCD_SNAPSHOT#|$ETCD_SNAPSHOT|g" $host-etcd-restore.script
 sed -i "s|#RESTORE_PATH#|$RESTORE_PATH|g" $host-etcd-restore.script
 sed -i "s|#INITIAL_CLUSTER#|$initial_cluster|g" $host-etcd-restore.script
 sed -i "s|#INITIAL_CLUSTER_TOKEN#|$token|g" $host-etcd-restore.script
 
 if [ "$this_host" = "$host" ] || [ "$this_host_ip" = "$ip" ];
  then
    prnt "Executing etcd restore on localhost($ip)"
    . $host-etcd-restore.script
  else
    prnt "Executing etcd restore on $ip"
   . execute-script-remote.sh $ip $host-etcd-restore.script
 fi
   mv $host-etcd-restore.script ./generated
 #generate systemd files
 mode=cluster
 . gen-systemd-config.sh $host $ip 

done
sed -i "s|#initial-cluster#|$initial_cluster|g" $gendir/*.service

#TODO 

cat vault/kube-apiserver.yaml | base64 -d >  kube.draft
sed -i "s|apiserver-etcd-client|$(hostname)-client|g" kube.draft
sed -i "s|host_ip|$(hostname -i)|g" kube.draft
sed -i "s|localhost|127.0.0.1|g" kube.draft
cp /etc/kubernetes/pki/etcd/$(hostname)-client.* /etc/kubernetes/pki/
sed -i "s|https://127.0.0.1:2379|$etcd_servers|g" kube.draft
#cp kube.draft /etc/kubernetes/manifests/kube-apiserver.yaml
#rm /etc/kubernetes/manifests/etcd.yaml
prnt "Snapshot spread over the etcd cluster! Readdy for launch"

