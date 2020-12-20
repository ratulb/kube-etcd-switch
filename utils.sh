#!/usr/bin/env bash
export usr=$(whoami)
read_setup() {
  etcd_ips=''
  etcd_names=''
  while IFS="=" read -r key value; do
    case "$key" in
      "etcd_servers") export etcd_servers="$value" ;;
      "kube_api_etcd_client_cert") export kube_api_etcd_client_cert="$value" ;;
      "kube_api_etcd_client_key") export kube_api_etcd_client_key="$value" ;;
      "etcd_ca") export etcd_ca="$value" ;;
      "etcd_key") export etcd_key="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "initial_cluster_token") export initial_cluster_token="$value" ;;
      "default_restore_path") export default_restore_path=$(echo $value | sed 's:/*$::') ;;
      "default_backup_loc") export default_backup_loc=$(echo $value | sed 's:/*$::') ;;
      "k8s_master") export k8s_master="$value" ;;
      "etcd_version") export etcd_version="$value" ;;
      "#"*) ;;
    esac
  done <"setup.conf"

  if [ -z "$k8s_master" ]; then
    echo -e "\e[31m No k8s_master found in setup.conf!!!\e[0m"
    exit 1
  fi
  
  export this_host_ip=$(echo $(hostname -i) | cut -d ' ' -f 1)
  export master_name=$(echo $k8s_master | cut -d':' -f 1)
  export master_ip=$(echo $k8s_master | cut -d':' -f 2)
  export kube_vault=${HOME}/.kube_vault/

  if [ -z "$etcd_servers" ]; then
    echo -e "\e[31m No etcd servers found in setup.conf!!!\e[0m"
    exit 1
  fi

  for svr in $etcd_servers; do
    pair=(${svr//:/ })
    etcd_name=${pair[0]}
    etcd_ip=${pair[1]}
    if [ -z "$etcd_ips" ]; then
      etcd_ips=$etcd_ip
      etcd_names=$etcd_name
    else
      etcd_ips+=' '$etcd_ip
      etcd_names+=' '$etcd_name
    fi
  done
  export etcd_ips=$etcd_ips
  export etcd_names=$etcd_names
}

"read_setup"

prnt() {
  echo -e "\e[1;42m$1\e[0m"
}

debug() {
  if [ ! -z "$debug" ]; then
    echo -e "\e[1;42m$1\e[0m"
  fi
}

err() {
  echo -e "\e[31m$1\e[0m"
}

warn() {
  echo -e "\e[31m$1\e[0m"
}
ask() {
  echo -e "\e[5m$1"
}

#Whatever is the default sleep_time
sleep_few_secs() {
  prnt "Sleeping few secs..."
  sleep $sleep_time
}

#Launch busybox container called debug
k8_debug() {
  prnt "Setting up busybox debug container"
  kubectl run -i --tty --rm debug --image=busybox:1.28 --restart=Never -- sh
}

install_etcdctl() {
  if ! [ -x "$(command -v etcdctl)" ]; then
    prnt "Installing etcdctl"
    ETCD_VER=$etcd_version
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
    prnt "etcdctl already installed"
  fi
}

gen_token() {
  cat .token &>/dev/null
  if [ ! $? = 0 ]; then
    identifier=$(date +%F_%H-%M-%S)
    echo "token=$identifier" >.token
  else
    identifier=$(cat .token | grep token | cut -d'=' -f 2)
    if [ -z "$identifier" ]; then
      identifier=$(date +%F_%H-%M-%S)
      echo "token=$identifier" >.token
    fi
  fi
  eval "$1=$identifier"
}

next_snapshot() {
  count=0
  if [ -d $default_backup_loc ]; then
    count=$(find $default_backup_loc/*.db -maxdepth 0 -type f | wc -l)
  else
    mkdir -p default_backup_loc
  fi
  ((count++))
  export NEXT_SNAPSHOT=$default_backup_loc/snapshot#$count.db
  echo "Next snapshot store path : $NEXT_SNAPSHOT"
}

last_snapshot() {
  last_snapshot=''
  if [ -d "$default_backup_loc" ]; then
    count=$(find $default_backup_loc -maxdepth 1 -type f -name "*.db" | wc -l)
    if [ $count ] >0; then
      last_snapshot=$(ls -t $default_backup_loc/*.db | head -n 1)
      last_snapshot=$(readlink -f $last_snapshot)
      export LAST_SNAPSHOT=$last_snapshot
      prnt "Last snapshot is: $last_snapshot"
    fi
  else
    err "No snapshot found in $default_backup_loc"
  fi
}

next_data_dir() {
  count=0
  if [ "$this_host_ip" = $1 ]; then
    count=$(ls -l $default_restore_path 2>/dev/null | grep -c ^d || mkdir -p $default_restore_path)
    if [ $count ] >0 && [ -d $default_restore_path/restore#$((count + 1)) ]; then
      ls -l $default_restore_path | grep ^d >list.txt
      cat list.txt | cut -d '#' -f 2 >sum.txt
      count=$(awk '{s+=$1} END {print s}' sum.txt)
    fi
  else
    count=$(sudo -u $usr ssh $1 "ls -l $default_restore_path 2>/dev/null | grep -c ^d  || mkdir -p $default_restore_path")
    if [ $count ] >0 && sudo -u $usr ssh $1 [ -d $default_restore_path/restore#$((count + 1)) ]; then
      sudo -u $usr ssh $1 ls -l $default_restore_path | grep ^d >list.txt
      cat list.txt | cut -d '#' -f 2 >sum.txt
      count=$(awk '{s+=$1} END {print s}' sum.txt)
    fi
  fi
  ((count++))
  rm -f list.txt sum.txt
  export NEXT_DATA_DIR=$default_restore_path/restore#$count
  echo "Next data dir for snapshot restore : $NEXT_DATA_DIR($1)"
}

purge_restore_path() {
  if [ "$this_host_ip" = $1 ]; then
    rm -rf $2
    echo "Purged : $2 on localhost($this_host_ip)"
  else
    sudo -u $usr ssh $1 "rm -rf $2"
    "Purged : $2 on remote host ($1)"
  fi
}

api_server_etcd_url() {
  _etcd_servers=''
  for ip in $etcd_ips; do
    if [ -z $_etcd_servers ]; then
      _etcd_servers=https://$ip:2379
    else
      _etcd_servers+=,https://$ip:2379
    fi
  done
  export API_SERVER_ETCD_URL=$_etcd_servers
  prnt "etcd server url for api server: $API_SERVER_ETCD_URL"

}

etcd_initial_cluster() {
  initial_cluster=''
  for svr in $etcd_servers; do
    pair=(${svr//:/ })
    host=${pair[0]}
    ip=${pair[1]}
    if [ -z $initial_cluster ]; then
      initial_cluster=$host=https://$ip:2380
    else
      initial_cluster+=,$host=https://$ip:2380
    fi
  done
  export ETCD_INITIAL_CLUSTER=$initial_cluster
  prnt "etcd initial cluster: $ETCD_INITIAL_CLUSTER"
}

dress_up_script() {
  case $1 in
    prepare-etcd-dirs.script)
      cp prepare-etcd-dirs.script prepare-etcd-dirs.script.tmp
      sed -i "3ibackup_loc=$default_backup_loc" prepare-etcd-dirs.script.tmp
      sed -i "4irestore_path=$default_restore_path" prepare-etcd-dirs.script.tmp
      ;;
    etcd-restore.script)
      cp etcd-restore.script etcd-restore.script.tmp
      sed -i "s|#ETCD_SNAPSHOT#|$2|g" etcd-restore.script.tmp
      sed -i "s|#RESTORE_PATH#|$3|g" etcd-restore.script.tmp
      sed -i "s|#TOKEN#|$4|g" etcd-restore.script.tmp
      ;;

    etcd-restore-cluster.script)
      cp etcd-restore-cluster.script etcd-restore-cluster.script.tmp
      sed -i "s|#ETCD_SNAPSHOT#|$2|g" etcd-restore-cluster.script.tmp
      sed -i "s|#RESTORE_PATH#|$3|g" etcd-restore-cluster.script.tmp
      sed -i "s|#TOKEN#|$4|g" etcd-restore-cluster.script.tmp
      sed -i "s|#INITIAL_CLUSTER#|$5|g" etcd-restore-cluster.script.tmp
      ;;

    *)
      echo "Not handled yet!"
      ;;
  esac
}
