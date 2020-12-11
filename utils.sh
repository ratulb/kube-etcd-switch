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
      "kube_api_client_cert") export kube_api_client_cert="$value" ;;
      "kube_api_client_key") export kube_api_client_key="$value" ;;
      "etcd_ca") export etcd_ca="$value" ;;
      "etcd_key") export etcd_key="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "initial_cluster_token") export initial_cluster_token="$value" ;;
      "data_dir") export data_dir=$(echo $value | sed 's:/*$::') ;;
      "default_backup_loc") export default_backup_loc=$(echo $value | sed 's:/*$::') ;;
      "k8s_master") export k8s_master="$value" ;;
      "#"*) ;;

    esac
  done < "setup.conf"
  export master_name=$(echo $k8s_master | cut -d':' -f 1)
  export master_ip=$(echo $k8s_master | cut -d':' -f 2)
  export kube_vault=${HOME}/.kube_vault/
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

 next_snapshot()
 {
  count=0
  if [ -d $default_backup_loc ]; 
    then
      count=$(find $default_backup_loc/*.db -maxdepth 0 -type f | wc -l)
    else
    mkdir -p default_backup_loc
  fi
  ((count++))
  export  NEXT_SNAPSHOT=$default_backup_loc/snapshot#$count.db
 }

latest_snapshot()
 {
  count=0
  if [ -d $default_backup_loc ]; then
    count=$(ls $default_backup_loc/*.db | wc -l)
  fi
  if [ $count = 0 ]; then 
    err "No snapshot found at $default_backup_loc. No backup has been taken or store location may have changed. Please check"
    exit 1
  fi
  export LATEST_SNAPSHOT=$default_backup_loc/snapshot#$count.db

 }

 next_data_dir()
 {  
    this_host_ip=$(hostname -i)
    count=0
    if [ $this_host_ip = $1 ]; 
      then
        count=$(ls -l $data_dir 2>/dev/null | grep -c ^d  || mkdir -p $data_dir)
      else
	count=$(ssh $1 "ls -l $data_dir 2>/dev/null | grep -c ^d  || mkdir -p $data_dir")
    fi
    export NEXT_DATA_DIR=$data_dir#$count
 }

purge_restore_path()
 {
    this_host_ip=$(hostname -i)
    if [ $this_host_ip = $1 ];
      then
	rm -rf $2
      else
	sudo -u $usr ssh $1 "rm -rf $2"
    fi
 }


