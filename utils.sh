#!/usr/bin/env bash 
#set -e
export usr=$(whoami)
read_setup()
{
  
  etcd_ips=
  etcd_names=
  initial_cluster_token=
  data_dir=
  default_restore_path=
  while IFS="=" read -r key value; do
    case "$key" in
      "etcd_servers") export etcd_servers="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "initial_cluster_token") export initial_cluster_token="$value" ;;
      "data_dir") export data_dir=$(echo $value | sed 's:/*$::') ;;
      "default_backup_loc") export default_backup_loc=$(echo $value | sed 's:/*$::') ;;
      "#"*) ;;

    esac
  done < "setup.conf"
}

"read_setup"

prnt()
{
 echo -e "\e[1;42m$1\e[0m"
}

err()
{
echo -e "\e[31m$1\e[0m"
}

warn()
{
echo -e "\e[31m$1\e[0m"
}
ask()
{
 echo -e "\e[5m$1"
}

#Whatever is the default sleep_time
sleep_few_secs()
{
 prnt "Sleeping few secs..."
 sleep $sleep_time
}

#Launch busybox container called debug
k8_debug()
{
 prnt "Setting up busybox debug container"
 kubectl run -i --tty --rm debug --image=busybox:1.28 --restart=Never -- sh 
}

install_etcdctl()
{
if ! [ -x "$(command -v etcdctl)" ]; 
   then 
     prnt "Installing etcdctl"
     ETCD_VER="3.4.14"
     ETCD_VER=${1:-$ETCD_VER}
     echo $ETCD_VER
     DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
     prnt "Downloading etcd $ETCD_VER from $DOWNLOAD_URL"
     wget -q --timestamping ${DOWNLOAD_URL}/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz -O /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
    rm -rf /tmp/etcd-download-loc
    mkdir /tmp/etcd-download-loc
    tar xzf /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-loc --strip-components=1
    mv /tmp/etcd-download-loc/etcdctl /usr/local/bin
    etcdctl version
  else
    prnt "etcdctl already installed" %> /dev/null
 fi
}

gen_token() {
 cat .token &> /dev/null
 if [ ! $? = 0 ]; then
  identifier=$(date +%F_%H-%M-%S)
  echo "token=$identifier" > .token
 else
   identifier=$(cat .token | grep token | cut -d'=' -f 2)
   if [ -z "$identifier" ]; then
     identifier=$(date +%F_%H-%M-%S)
     echo "token=$identifier" > .token
   fi
 fi
 eval "$1=$identifier"
 }
