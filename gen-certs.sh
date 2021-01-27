#!/usr/bin/env bash
. utils.sh
. checks/ca-cert-existence.sh
servers=$etcd_servers
if [ "$#" -gt 0 ]; then
  servers=$@
fi
prnt "Generating certificates for $servers"

rm -f ${gendir}/*.crt
rm -f ${gendir}/*.key
count=0
for host_and_ip in $servers; do
  host=$(echo $host_and_ip | cut -d':' -f1)
  ip=$(echo $host_and_ip | cut -d':' -f2)
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
  prnt "Generated certs for $host"
  ((count++))
done
cd $gendir
rm ./*.json
rm ./*.csr

for file in $(ls . | grep "\-key.pem$"); do mv "$file" "${file%-*}.key"; done
for file in $(ls . | grep ".pem$"); do mv "$file" "${file%.*}.crt"; done

cd - &>/dev/null

count=$((count * 6))
tree | grep generated -A$count
