#!/usr/bin/env bash
#Generates the certicates for etcd servers using cfssl and ca.crt file from /etc/kubernetes/pki/etcd by default. Any ca can be used used overriding the default - as long apiserver certs can use the ca. 
. utils.sh

etcd_ca=${etcd_ca:-"/etc/kubernetes/pki/etcd/ca.crt"}
etcd_key=${etcd_key:-"/etc/kubernetes/pki/etcd/ca.key"}

if [ ! -f $etcd_ca ] || [ ! -f $etcd_key ]; then
    err_msg "$etcd_ca or/and $etcd_key not present!"
    exit 1
fi

prnt_msg "Etcd servers from setup.conf"
for svr in $etcd_servers; do
  prnt_msg $svr
done

echo  "Please make sure $HOME/.ssh/id_rsa.pub SSH public key has been copied \
to etcd servers!"

#read -p "Proceed with certificate generation? " -n 1 -r
#if [[ ! $REPLY =~ ^[Yy]$ ]]
#then
 #   err_msg "\nAborted certificate generation\n"
  #  exit 1
#fi
 . install-cfssl.sh
gendir=./generated
mkdir -p ${gendir}
rm -f ${gendir}/*.crt
rm -f ${gendir}/*.key
count=0
for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 
 if [ -z $host ] || [ -z $ip ];
   then
     err_msg "Host or IP address is not valid - can not proceed!"
     rm -rf $gendir
     exit 1
 fi
 
 cp ./csr-template.json ${gendir}/${host}-csr.json 
 sed -i "s/#etcd-host#/${host}/g" ${gendir}/${host}-csr.json
 
 cfssl gencert \
  -ca=${etcd_ca} \
  -ca-key=${etcd_key} \
  -config=ca-csr.json \
  -profile=client \
  -hostname=${host},${ip},127.0.0.1,localhost \
  ${gendir}/${host}-csr.json | cfssljson -bare ${gendir}/${host}-client

 cfssl gencert \
  -ca=${etcd_ca} \
  -ca-key=${etcd_key} \
  -config=ca-csr.json \
  -hostname=${host},${ip},127.0.0.1,localhost \
  -profile=peer \
  ${gendir}/${host}-csr.json | cfssljson -bare ${gendir}/${host}-peer
 
 cfssl gencert \
  -ca=${etcd_ca} \
  -ca-key=${etcd_key} \
  -config=ca-csr.json \
  -hostname=${host},${ip},127.0.0.1,localhost \
  -profile=server \
  ${gendir}/${host}-csr.json | cfssljson -bare ${gendir}/${host}-server

 ((count++))
done

cd $gendir

rm ./*.json
rm ./*.csr

for file in $(ls . | grep "\-key.pem$"); do mv "$file" "${file%-*}.key"; done
for file in $(ls . | grep ".pem$"); do mv "$file" "${file%.*}.crt"; done

cd - &> /dev/null

count=$((count*6))
tree | grep generated -A$count


