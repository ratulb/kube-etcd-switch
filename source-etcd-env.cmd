
echo "ETCDCTL_API=3 etcdctl member list --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/master-server.crt --key=/etc/kubernetes/pki/etcd/master-server.key --endpoints=https://10.148.0.58:2379"

export ETCD_NAME=https://$(hostname -i):2379
export ETCD_CA_FILE=/etc/kubernetes/pki/etcd/ca.crt
export ETCD_CERT_FILE=/etc/kubernetes/pki/etcd/$(hostname)-server.crt
export ETCD_KEY_FILE=/etc/kubernetes/pki/etcd/$(hostname)-server.key


