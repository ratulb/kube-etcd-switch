#!/usr/bin/env bash
#Generates the certicates for etcd servers
. utils.sh

etcd_ca=/etc/kubernetes/pki/etcd/ca.crt
etcd_key=/etc/kubernetes/pki/etcd/ca.key

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

read -p "Proceed with certificate generation? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err_msg "\nAborted certificate generation\n"
    exit 1
fi

gendir=./generated
mkdir -p ${gendir}

for svr in $etcd_servers; do
 pair=(${svr//:/ })
 host=${pair[0]}
 ip=${pair[1]}
 #prnt_msg "\nHost: $host and IP $ip"
 
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
  -config=ca-config.json \
  -hostname=${host},${ip} \
  -profile=server \
  ${gendir}/${host}-csr.json | cfssljson -bare ${gendir}/${host}
 
  if [ -d /etc/kubernetes/pki/etcd  ];
    then
      if [ `hostname` = "$host" ];
        then 
	  if [ "$(hostname -i)" = "$ip" ];
	    then
	      cd $gendir
	      mv $host-key.pem $host.key
	      mv $host.pem $host.crt
	      cp $host.key /etc/kubernetes/pki/etcd
	      cp $host.crt /etc/kubernetes/pki/etcd
	      cd -
          fi	      
       fi
  fi
	
done

cd $gendir
rm ./*.json
rm ./*.csr
for file in $(ls . | grep "\-key.pem$"); do mv "$file" "${file%-*}.key"; done
for file in $(ls . | grep ".pem$"); do mv "$file" "${file%.*}.crt"; done
cd -
