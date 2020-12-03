#!/usr/bin/env bash 
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
 echo " check 1 $host"
 echo " check 2 $ip"
 echo " check 3 `hostname`"
 echo " check 4 $(hostname -i)"
 
 host_ip=$(hostname -i)

 echo "host_ip : $host_ip"

 if  [ "$hostname = $host" ] && [  "$(hostname -i) = $ip " ]  
    then echo This host yes
    else echo Not this host
 fi
}

