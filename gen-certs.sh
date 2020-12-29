#!/usr/bin/env bash
. utils.sh
. checks/ca-cert-existence.sh

prnt "Generating certificates for:"
for svr in $etcd_servers; do
  prnt $svr
done

rm -f ${gendir}/*.crt
rm -f ${gendir}/*.key
count=0
#for svr in $etcd_servers; do
for host in "${!mappings[@]}"
 #pair=(${svr//:/ })
 #host=${pair[0]}
 #ip=${pair[1]}
 ip=${mappings[${host}]}
 
 if [ -z $host ] || [ -z $ip ];
   then
     err "Host or IP address is not valid - can not proceed!"
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


