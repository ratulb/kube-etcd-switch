#!/usr/bin/env bash
#Does a restore of local etcd based on snapshot using generated certs or already existing certs in /etc/kubernetets/pki/etcd. Snapshot location(ETCD_SNAPSHOT), restore path(RESTORE_PATH i.e. --data-dir) and what certificates to use for restoring the backup can be controlled. /etc/kubernetes/pki/server.crt is kubeadm generated cert whereas /etc/kubernetes/pki/master.crt - would mean a cert generated by using the gen-certs.sh for a machine named master.

#ETCD_SNAPSHOT=./backups/server-cert.db ETCD_CERT=server ./local-restore.sh 
. utils.sh
  
install_etcdctl

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-/var/lib/etcd-snapshot.db}
IP_ADDRESS=$(hostname -i)
ETCD_CERT=${ETCD_CERT:-$(hostname)}

if [ ! -f ${ETCD_SNAPSHOT} ]; then
    err_msg "Snapshot path ${ETCD_SNAPSHOT} does not exists!"
    exit 1
fi

etcdctl snapshot status ${ETCD_SNAPSHOT} || exit_code=$?
if (( exit_code > 1 )) ; 
  then
    err_msg "Status check on the snapshot returned $exit_code. Is the snapshot corrupt?"
    exit $exit_code
  else
    prnt_msg "etcd snapshot ${ETCD_SNAPSHOT} looks good!"
fi

restored_at=$(date +%F_%H-%M-%S)
RESTORE_PATH=${RESTORE_PATH:-/var/lib/restore-$restored_at}

prnt_msg "Going to restore at location: ${RESTORE_PATH}"
rm -rf $RESTORE_PATH

ETCDCTL_API=3 etcdctl snapshot restore $ETCD_SNAPSHOT --name=$(hostname) --data-dir=$RESTORE_PATH --initial-advertise-peer-urls=https://${IP_ADDRESS}:2380 --initial-cluster $(hostname)=https://${IP_ADDRESS}:2380 --initial-cluster-token=${RESTORE_PATH} --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/${ETCD_CERT}.crt --key=/etc/kubernetes/pki/etcd/${ETCD_CERT}.key --endpoints=https://${IP_ADDRESS}:2379

mv /etc/kubernetes/manifests/kube-apiserver.yaml .
mv /etc/kubernetes/manifests/etcd.yaml . 
cp etcd.yaml .etcd.yaml.copy

OLD_DATA_DIR=$(cat etcd.yaml | grep "\-\-data-dir=")
OLD_DATA_DIR=${OLD_DATA_DIR:17}
sed -i "s|$OLD_DATA_DIR|$RESTORE_PATH|g" etcd.yaml

#initial-cluster-token
sed -i '/initial-cluster-token/d' etcd.yaml
sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=restore-$restored_at" etcd.yaml    

#OLD_INIT_CLUSTER_TOKEN=${OLD_INIT_CLUSTER_TOKEN:30}
#sed -i "s|$OLD_INIT_CLUSTER_TOKEN|restore-$restored_at|g" etcd.yaml

mv etcd.yaml /etc/kubernetes/manifests/
mv kube-apiserver.yaml /etc/kubernetes/manifests/

systemctl restart kubelet
sleep 2
prnt_msg "Post etcd restore - checking kube-system pods..."
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

prnt_msg "Snapshot restored"
