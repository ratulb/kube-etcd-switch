#!/usr/bin/env bash
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 'hostname' 'ip'"
  exit 1
fi
. utils.sh
. checks/ca-cert-existence.sh
host=$1
ip=$2
 
cp ./csr-template.json ${gendir}/${host}-csr.json 
sed -i "s/#etcd-host#/${host}/g" ${gendir}/${host}-csr.json
 
cfssl gencert \
  -ca=${etcd_ca} \
  -ca-key=${etcd_key} \
  -config=ca-csr.json \
  -profile=client \
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

cd $gendir

rm ./*.json
rm ./*.csr

for file in $(ls . | grep "\-key.pem$"); do mv "$file" "${file%-*}.key"; done
for file in $(ls . | grep ".pem$"); do mv "$file" "${file%.*}.crt"; done

cd - &> /dev/null

prnt "Generated certificate and key for $host($ip)"
