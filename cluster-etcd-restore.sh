#!/usr/bin/env bash
  

ETCD_SNAPSHOT=${ETCD_SNAPSHOT:-/var/lib/etcd-snapshot.db}
IP_ADDRESS=$(hostname -i)
ETCD_CERT=${ETCD_CERT:-$(hostname)}

restored_at=$(date +%F_%H-%M-%S)
RESTORE_PATH=${RESTORE_PATH:-/var/lib/restore-$restored_at}

prnt  "Would restore from $ETCD_SNAPSHOT at $RESTORE_PATH ok? Can change restore locations(from/to) by setting the ETCD_SNAPSHOT/RESTORE_PATH environment variables."
read -p "Proceed with restore? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err "\nAborted backup restore.\n"
    exit 1
fi
if [ ! -f ${ETCD_SNAPSHOT} ]; then
    err "Snapshot path ${ETCD_SNAPSHOT} does not exists!"
    exit 1
fi

etcdctl snapshot status ${ETCD_SNAPSHOT} || exit_code=$?
if (( exit_code > 1 )) ; 
  then
    err "Status check on the snapshot returned $exit_code. Is the snapshot corrupt?"
    exit $exit_code
  else
    prnt "etcd snapshot ${ETCD_SNAPSHOT} looks good!"
fi


prnt "Restoring at location: ${RESTORE_PATH}"
rm -rf $RESTORE_PATH

ETCDCTL_API=3 etcdctl snapshot restore $ETCD_SNAPSHOT --name=$(hostname) --data-dir=$RESTORE_PATH --initial-advertise-peer-urls=https://${IP_ADDRESS}:2380 --initial-cluster $(hostname)=https://${IP_ADDRESS}:2380 --initial-cluster-token=${RESTORE_PATH} --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/${ETCD_CERT}.crt --key=/etc/kubernetes/pki/etcd/${ETCD_CERT}.key --endpoints=https://${IP_ADDRESS}:2379

mv /etc/kubernetes/manifests/kube-apiserver.yaml .

if [ -f /etc/kubernetes/manifests/etcd.yaml ];
  then 
    mv /etc/kubernetes/manifests/etcd.yaml .etcd.yaml
    cp .etcd.yaml etcd.draft
  else
    encoded=$(basename -- "$ETCD_SNAPSHOT")
    encoded="${encoded%.*}"
    SNAPSHOT_DIR=${ETCD_SNAPSHOT%/*}
    cat $SNAPSHOT_DIR/$encoded.nodelete | base64 -d > etcd.draft
fi

if [ ! -f etcd.draft ]; then
 err "Unable to locate etcd.yaml in the system. Not proceeding with restore!"
 exit 1
fi

OLD_DATA_DIR=$(cat etcd.draft | grep "\-\-data-dir=")
OLD_DATA_DIR=${OLD_DATA_DIR:17}
sed -i "s|$OLD_DATA_DIR|$RESTORE_PATH|g" etcd.draft

#initial-cluster-token
sed -i '/initial-cluster-token/d' etcd.draft
sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=restore-$restored_at" etcd.draft

mv etcd.draft /etc/kubernetes/manifests/etcd.yaml
mv kube-apiserver.yaml /etc/kubernetes/manifests/

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

prnt "Snapshot restored"

