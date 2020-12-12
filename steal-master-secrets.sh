#!/usr/bin/env bash 
echo 'Copies of pristine kubernetes yamls' > $kube_vault/README.txt

sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
        UserKnownHostsFile=/dev/null \
        $1:/etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} \
        $kube_vault/
prnt "Storing etcd and api server yamls @$kube_vault"
sudo -u $usr chown -R $(id -u):$(id -g) /etc/kubernetes/pki/ 
if [ "$(hostname -i)" = $1 ]; then
  exit 0
fi

mkdir -p /etc/kubernetes/pki/etcd/
sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
	UserKnownHostsFile=/dev/null \
	$1:/etc/kubernetes/pki/etcd/{ca.crt,ca.key} \
	/etc/kubernetes/pki/etcd/

sudo -u $usr scp -q -o StrictHostKeyChecking=no -o \
        UserKnownHostsFile=/dev/null \
        $1:/etc/kubernetes/pki/{apiserver-etcd-client.crt,apiserver-etcd-client.key} \
        /etc/kubernetes/pki/
prnt "Copied ca and api server certs..."
