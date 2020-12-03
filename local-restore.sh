#!/usr/bin/env bash
#Does a restore of local etcd based on snapshot using generated certs
. utils.sh
  
install_etcdctl

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-/var/lib/etcd-snapshot.db}
IP_ADDRESS=$(hostname -i)

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

ETCDCTL_API=3 etcdctl snapshot restore $ETCD_SNAPSHOT --name=$(hostname) --data-dir=$RESTORE_PATH --initial-advertise-peer-urls=https://${IP_ADDRESS}:2380 --initial-cluster $(hostname)=https://${IP_ADDRESS}:2380 --initial-cluster-token=${RESTORE_PATH} --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/${hostname}.crt --key=/etc/kubernetes/pki/etcd/${hostname}.key --endpoints=https://${IP_ADDRESS}:2379

mv /etc/kubernetes/manifests/kube-apiserver.yaml .
mv /etc/kubernetes/manifests/etcd.yaml . 
cp etcd.yaml etcd.yaml.copy

OLD_DATA_DIR=$(cat etcd.yaml | grep "\-\-data-dir=")
OLD_DATA_DIR=${OLD_DATA_DIR:17}
sed -i "s|$OLD_DATA_DIR|$RESTORE_PATH|g" etcd.yaml

OLD_INIT_CLUSTER_TOKEN=$(cat etcd.yaml | grep initial-cluster-token)
OLD_INIT_CLUSTER_TOKEN=${OLD_INIT_CLUSTER_TOKEN:30}

sed -i "s|$OLD_INIT_CLUSTER_TOKEN|restore-$restored_at|g" etcd.yaml

mv etcd.yaml /etc/kubernetes/manifests/

sleep_few_secs

mv kube-apiserver.yaml /etc/kubernetes/manifests/

prnt_msg "Snapshot restored"

kubectl get pod
