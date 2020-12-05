#!/usr/bin/env bash 
#set -e
export usr=$(whoami)
read_setup()
{
  
  etcd_ips=
  etcd_names=
  while IFS="=" read -r key value; do
    case "$key" in
      "etcd_servers") export etcd_servers="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "#"*) ;;

    esac
  done < "setup.conf"
}

"read_setup"

prnt_msg()
{
 echo -e "\e[1;42m$1\e[0m"
}

err_msg()
{
echo -e "\e[31m$1\e[0m"
}
conf_msg()
{
 echo -e "\e[5m$1"
}

#Whatever is the default sleep_time
sleep_few_secs()
{
 prnt_msg "Sleeping few secs..."
 sleep $sleep_time
}

#Launch busybox container called debug
k8_debug()
{
 prnt_msg "Setting up busybox debug container"
 kubectl run -i --tty --rm debug --image=busybox:1.28 --restart=Never -- sh 
}

function install_etcdctl
{
if ! [ -x "$(command -v etcdctl)" ]; 
   then 
     prnt_msg "Installing etcdctl"
     ETCD_VER="3.4.14"
     ETCD_VER=${1:-$ETCD_VER}
     DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
     prnt_msg "Downloading etcd $ETCD_VER from $DOWNLOAD_URL"
     wget -q --timestamping ${DOWNLOAD_URL}/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz -O /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
    rm -rf /tmp/etcd-download-loc
    mkdir /tmp/etcd-download-loc
    tar xzf /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-loc --strip-components=1
    mv /tmp/etcd-download-loc/etcdctl /usr/local/bin
    etcdctl version
  else
    prnt_msg "etcdctl already installed"
    which etcdctl
 fi
}


function test1 {


 OLD_INIT_CLUSTER_TOKEN=$(cat etcd.yaml | grep initial-cluster-token)
 echo "check 0 : $OLD_INIT_CLUSTER_TOKEN"
 if [ ! -z "${OLD_INIT_CLUSTER_TOKEN}"  ]; then
     echo "check1"
     OLD_INIT_CLUSTER_TOKEN=${OLD_INIT_CLUSTER_TOKEN:30}
     echo "check2 : $OLD_INIT_CLUSTER_TOKEN"
     sed -i "s|$OLD_INIT_CLUSTER_TOKEN|restore-$restored_at|g" etcd.yaml
     echo "check3"
   else
     echo "check4"
     sed -i "/--client-cert-auth=true/a\    \- --initial-cluster-token=restore-$restored_at" etcd.yaml
     echo "check5"
 fi


}

