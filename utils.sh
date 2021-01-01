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
    err "No k8s_master found in setup.conf!"
    #exit 1
  fi

  export this_host_ip=$(echo $(hostname -i) | cut -d ' ' -f 1)
  export master_name=$(echo $k8s_master | cut -d':' -f 1)
  export master_ip=$(echo $k8s_master | cut -d':' -f 2)
  export kube_vault=${HOME}/.kube_vault
  export gendir=$(pwd)/generated

  if [ -z "$etcd_servers" ]; then
    echo -e "\e[31mNo etcd servers found in setup.conf!\e[0m"
    #exit 1
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
  echo -e $"\e[01;32m$1\e[0m"
}

debug() {
  if [ ! -z "$debug" ]; then
    err "$1"
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
  prnt "Waiting few secs..."
  sleep $sleep_time
}

can_access_ip() {
  if [ "$1" == $this_host_ip ]; then
    return 0
  else
    . execute-command-remote.sh $1 ls -la &>/dev/null
  fi
}

is_master_ip_set() {
  [ ! -z "$master_ip" ] && is_ip $master_ip
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

is_ip() {
  address=$1
  rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
  if [[ "$address" =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
    debug "$address is valid ip"
    return 0
  else
    err "$address is not valid ip"
    return 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    err "$1 not installed. Stopping execution. Has the system been initialized?"
    exit 1
  fi
}

check_file_existence() {
  host=$1
  shift
  files=$@
  for f in $files; do
    if [ "$host" = $this_host_ip ]; then
      if [ ! -s $f ]; then
        return 1
      fi
    else
      . execute-command-remote.sh $host "[[ -s $f ]]"
      if [ "$?" -eq 1 ]; then
        return 1
      fi
    fi
  done
  return 0
}

check_system_init_reqrmnts_met() {
  required_files="/etc/kubernetes/pki/apiserver-etcd-client.crt /etc/kubernetes/pki/apiserver-etcd-client.key /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.key /etc/kubernetes/manifests/kube-apiserver.yaml ~/.kube/config"
  if [ -z "$2" ]; then
    required_files="$required_files /etc/kubernetes/manifests/etcd.yaml"
  fi
  check_file_existence $1 $required_files || return 1
}

gen_token() {
  cat $gendir/.token &>/dev/null
  if [ ! $? = 0 ]; then
    identifier=$(date +%F_%H-%M-%S)
    echo "token=$identifier" >$gendir/.token
  else
    identifier=$(cat $gendir/.token | grep token | cut -d'=' -f 2)
    if [ -z "$identifier" ]; then
      identifier=$(date +%F_%H-%M-%S)
      echo "token=$identifier" >$gendir/.token
    fi
  fi
  eval "$1=$identifier"
}

next_snapshot() {
  count=0
  search="*.db"
  if [ ! -z $1 ]; then
    search="$1-*.db"
  fi
  if [ -d $default_backup_loc ]; then
    count=$(find $default_backup_loc/$search -maxdepth 0 -type f 2>/dev/null | wc -l)
  else
    mkdir -p $default_backup_loc
  fi
  ((count++))
  export NEXT_SNAPSHOT=$default_backup_loc/$1-snapshot#$count.db
  debug "Next snapshot store path : $NEXT_SNAPSHOT"
  prnt "Next snapshot name: $(basename $NEXT_SNAPSHOT)"
}

last_snapshot() {
  if is_default_backup_loc_initialized; then
    unset LAST_SNAPSHOT
    search="*.db"
    if [ ! -z $1 ]; then
      search="$1-*.db"
    fi
    count=$(find $default_backup_loc -maxdepth 1 -type f -name "$search" | wc -l)
    if [ $count -gt 0 ]; then
      last_snapshot=$(ls -t $default_backup_loc/$search | head -n 1)
      last_snapshot=$(readlink -f $last_snapshot)
      export LAST_SNAPSHOT=$last_snapshot
      debug "Last snapshot is: $last_snapshot"
    else
      if [ -z $1 ]; then
        debug "No last snapshot found in $default_backup_loc"
      else
        debug "No last $1 snapshot found in $default_backup_loc"
      fi
    fi
  fi
}

is_default_backup_loc_initialized() {
  if [ -d $default_backup_loc ]; then
    return 0
  else
    err "Default backup directory not found. Has the system been initialized?"
    return 1
  fi
}

list_snapshots() {
  if is_default_backup_loc_initialized; then
    count=$(find $default_backup_loc -maxdepth 1 -type f -name "*.db" | wc -l)
    if [ $count -gt 0 ]; then
      prnt "Snapshots"
      find $default_backup_loc -maxdepth 1 -type f -name *.db | xargs -n1 basename | cut -d '.' -f 1 | sort
    else
      err "No snapshot found."
    fi
  fi
}

delete_snapshots() {
  if is_default_backup_loc_initialized; then
    case $1 in
      '')
        err "Delete snapshot - None selected!"
        ;;
      -a | --all)
        count=$(find $default_backup_loc -maxdepth 1 -type f -name "*.db" | wc -l)
        if [ $count -gt 0 ]; then
          rm $default_backup_loc/*.db
          prnt "Deleted $count snaspshots"
        else
          err "No snapshot to delete"
        fi
        ;;
      *)
        deleted=''
        not_deleted=''
        for f in "$@"; do
          if [ -f $default_backup_loc/$f.db ]; then
            rm $default_backup_loc/$f.db
            if [ -z "$deleted" ]; then
              deleted=$f
            else
              deleted="$deleted $f"
            fi
          else
            if [ -z "$not_deleted" ]; then
              not_deleted=$f
            else
              not_deleted="$not_deleted $f"
            fi
          fi
        done
        if [ ! -z "$deleted" ]; then
          prnt "Deleted $deleted"
        fi
        if [ ! -z "$not_deleted" ]; then
          err "Not deleted $not_deleted because not found."
        fi
        ;;
    esac
  fi
}

last_saved_state() {
  if is_kube_vault_initialized; then
    unset LAST_SAVE
    last_archive=''
    search="*.tar.gz"
    if [ ! -z "$1" ]; then
      search="$1*.tar.gz"
    fi
    count=$(find $kube_vault/migration-archive -maxdepth 1 -type f -name "$search" | wc -l)
    if [ $count -gt 0 ]; then
      last_archive=$(ls -t $kube_vault/migration-archive/$search | head -n 1)
      last_archive=$(readlink -f $last_archive)
      export LAST_SAVE=$last_archive
      debug "Last saved state is: $LAST_SAVE"
    else
      if [ -z "$1" ]; then
        debug "No saved state found in $kube_vault/migration-archive"
      else
        debug "Saved state $1 not found in $kube_vault/migration-archive"
      fi
    fi
  fi
}

is_kube_vault_initialized() {
  if [ -d $kube_vault ]; then
    return 0
  else
    err "kube vault not found. Has the system been initialized?"
    return 1
  fi
}

list_saved_states() {
  if is_kube_vault_initialized; then
    count=$(find $kube_vault/migration-archive -maxdepth 1 -type f -name "*.tar.gz" | wc -l)
    if [ $count -gt 0 ]; then
      prnt "Last good states"
      #find $kube_vault/migration-archive -maxdepth 1 -type f -name *.tar.gz | xargs -n1 basename | cut -d '.' -f 1 | sort
      ls -lat $kube_vault/migration-archive/*.tar.gz | awk '{print $9}' | xargs -n1 basename | cut -d '.' -f 1
    else
      err "No last good state found."
    fi
  fi
}

delete_saved_states() {
  if is_kube_vault_initialized; then
    case $1 in
      '')
        err "No parameters supplied!"
        ;;
      -a | --all)
        count=$(find $kube_vault/migration-archive -maxdepth 1 -type f -name "*.tar.gz" | wc -l)
        if [ $count -gt 0 ]; then
          rm $kube_vault/migration-archive/*.tar.gz
          prnt "Deleted $count saved states"
        else
          err "No saved state to delete"
        fi
        ;;
      *)
        deleted=''
        not_deleted=''
        for f in "$@"; do
          if [ -f $kube_vault/migration-archive/$f.tar.gz ]; then
            rm $kube_vault/migration-archive/$f.tar.gz
            if [ -z "$deleted" ]; then
              deleted=$f
            else
              deleted="$deleted $f"
            fi
          else
            if [ -z "$not_deleted" ]; then
              not_deleted=$f
            else
              not_deleted="$not_deleted $f"
            fi
          fi
        done
        if [ ! -z "$deleted" ]; then
          prnt "Deleted $deleted"
        fi
        if [ ! -z "$not_deleted" ]; then
          err "Not deleted $not_deleted because not found."
        fi
        ;;
    esac
  fi
}

saved_state_exists() {
  last_saved_state $1
  [ -f "$LAST_SAVE" ]
}

saved_snapshot_exists() {
  last_snapshot $1
  [ -f "$LAST_SNAPSHOT" ]
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
      . execute-command-remote.sh $1 "ls -l $default_restore_path | grep ^d >list.txt"
      cat list.txt | cut -d '#' -f 2 >sum.txt
      count=$(awk '{s+=$1} END {print s}' sum.txt)
    fi
  fi
  ((count++))
  rm -f list.txt sum.txt
  export NEXT_DATA_DIR=$default_restore_path/restore#$count
  prnt "Next data dir for snapshot restore : $(basename $NEXT_DATA_DIR)($1)"
  debug "Next data dir for snapshot restore : $NEXT_DATA_DIR($1)"
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
      echo "Not my case!"
      ;;
  esac
}
