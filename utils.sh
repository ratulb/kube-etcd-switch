#!/usr/bin/env bash
export usr=$(whoami)

prnt() {
  echo -e $"\e[92m$1\e[0m"
}

err() {
  echo -e "\e[31m$1\e[0m"
}

warn() {
  echo -e "\e[33m$1\e[0m"
}

debug() {
  if [ ! -z "$debug" ]; then
    echo -e "\e[36m$1\e[0m"
  fi
}

#Need further check for duplicate ip and host name
normalize_etcd_entries() {
  current_entries=$(cat setup.conf | grep etcd_servers= | cut -d '=' -f 2 | xargs)
  if [ ! -z "$current_entries" ]; then
    debug "normalize_etcd_entries: current entries: $current_entries"
    normalized_entries=''

    for entry in $current_entries; do
      if [[ ! "$normalized_entries" =~ "$entry" ]]; then
        normalized_entries+=" $entry"
      fi
    done
    normalized_entries=$(echo $normalized_entries | xargs)
    debug "normalize_etcd_entries: $normalized_entries"
    sed -i "s|$current_entries|$normalized_entries|g" setup.conf
  fi
}

read_setup() {
  etcd_ips=''
  etcd_names=''
  while IFS="=" read -r key value; do
    case "$key" in
      "etcd_servers") export etcd_servers="$value" ;;
      "etcd_ca") export etcd_ca="$value" ;;
      "etcd_key") export etcd_key="$value" ;;
      "sleep_time") export sleep_time="$value" ;;
      "initial_cluster_token") export initial_cluster_token="$value" ;;
      "default_restore_path") export default_restore_path=$(echo $value | sed 's:/*$::') ;;
      "default_backup_loc") export default_backup_loc=$(echo $value | sed 's:/*$::') ;;
      "masters") export masters="$value" ;;
      "etcd_version") export etcd_version="$value" ;;
      "kube_install_git_repo") export kube_install_git_repo="$value" ;;
      "#"*) ;;
    esac
  done <"setup.conf"

  if [ -z "$masters" ]; then
    warn "No masters found in setup.conf"
  else
    export master_address=$(echo $masters | cut -d' ' -f1)
  fi

  if [ -z "$etcd_servers" ]; then
    warn "No etcd servers found in setup.conf"
  else
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
  fi

  export this_host_ip=$(echo $(hostname -i) | cut -d ' ' -f 1)
  export this_host_name=$(hostname)
  export kube_vault=${HOME}/.kube_vault
  export gendir=$(pwd)/generated
}

"normalize_etcd_entries"
"read_setup"

ca_exists() {
  err_msg="Can not find etcd ca - can not proceed! Has the system been initialized?"
  ([ -s "$etcd_ca" ] && [ -s "$etcd_key" ]) || (err "$err_msg" && return 1)
}
client_cert_exists() {
  ([ -s /etc/kubernetes/pki/etcd/$(hostname)-client.crt ] && [ -s /etc/kubernetes/pki/etcd/$(hostname)-client.key ]) || (err "API client cert/key missing" && return 1)
}

remote_script() {
  #prnt "Executing on $1"
  sudo -u $usr ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 $1 <$2
}
remote_cmd() {
  remote_host=$1
  if [ -z "$quiet" ]; then
    : #prnt "Executing command on $remote_host"
  fi
  shift
  args="$@"
  sudo -u $usr ssh -q -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" $remote_host $args
}
remote_copy() {
  sudo -u $usr scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null $1 $2
}

ask() {
  echo -e "\e[5m$1"
}

#Whatever is the default sleep_time
sleep_few_secs() {
  prnt "Waiting few secs..."
  sleep $sleep_time
}

can_ping_address() {
  if is_address_local $1; then
    return 0
  fi
  local ip=$1
  debug "Pinging ip $ip"
  #ping -q -c 3 $ip &>/dev/null || return 1
  fping -c 1 -t 1000 $ip &>/dev/null || return 1
}

is_address_local() {
  local addr=$1
  if [[ "$addr" = $this_host_ip ]] || [[ "$addr" = "$this_host_name" ]] || [[ "$addr" = "127.0.0.1" ]] || [[ "$ad
dr" = "localhost" ]]; then
    return 0
  else
    return 1
  fi
}

can_access_ip() {
  if [ "$1" = "$this_host_ip" ]; then
    return 0
  else
    remote_cmd $1 ls -la &>/dev/null
  fi
}
is_master_set() {
  #[[ ! -z "$master_address" ]] && (is_ip $master_address || is_host_name_ok $master_address)
  [[ ! -z "$master_address" ]] && can_access_address $master_address
}

upsert_etcd_server_list() {
  local nodes_being_added=$@
  existing_nodes=$etcd_servers
  in_all="$existing_nodes $nodes_being_added"
  in_all=$(echo $in_all | xargs)
  accessible_de_duplicated=''
  for entry in $in_all; do
    entry_ip=$(echo $entry | cut -d':' -f2)
    if can_access_address $entry_ip && ! [[ "$accessible_de_duplicated" = *"$entry"* ]]; then
      accessible_de_duplicated+="$entry "
    fi
  done
  accessible_de_duplicated=$(echo $accessible_de_duplicated | xargs)
  sed -i "s/etcd_servers=.*/etcd_servers=$accessible_de_duplicated/g" setup.conf
  read_setup
}

prune_etcd_server_list() {
  [[ -z "$etcd_servers" ]] && return 0
  nodes_being_deleted=$@
  nodes_being_deleted=$(echo $nodes_being_deleted | xargs)
  local old_etcd_servers=$(cat setup.conf | grep etcd_servers= | cut -d '=' -f 2)
  old_etcd_servers=$(echo $old_etcd_servers | xargs)
  new_server_list=''
  for node in $old_etcd_servers; do
    if ! [[ "$nodes_being_deleted" = *"$node"* ]]; then
      new_server_list+=" $node"
    fi
  done
  new_server_list=$(echo $new_server_list | xargs)
  sed -i "s/etcd_servers=.*/etcd_servers=$new_server_list/g" setup.conf
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
  local address=$1
  local rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
  if [[ "$address" =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
    debug "$address is valid ip"
    return 0
  else
    debug "$address is not valid ip"
    return 1
  fi
}

#A simple check - revisit if required
is_host_name_ok() {
  local rx="^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$"
  [[ $1 =~ $rx ]] && debug "hostname is ok" || return 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    return 1
  else
    return 0
  fi

}

can_access_address() {
  local _addr=$1
  if ! is_ip $_addr && ! is_host_name_ok $_addr; then
    err "Address is not valid"
    return 1
  fi
  if is_address_local $_addr; then
    return 0
  else
    remote_cmd $1 ls -la &>/dev/null
    if [ "$?" -eq 0 ]; then
      debug "$_addr is accessible"
    else
      (err "Can not access $_addr" && return 1)
    fi
  fi
}

check_file_existence() {
  local host=$1
  shift
  files=$@
  for f in $files; do
    if [ "$host" = $this_host_ip ]; then
      if [ ! -s $f ]; then
        if [ ! -z "$debug" ]; then
          err "File existence check failed for $f at localhost"
        fi
        return 1
      fi
    else
      remote_cmd $host "[[ -s $f ]]"
      if [ "$?" -eq 1 ]; then
        if [ ! -z "$debug" ]; then
          err "File existence check failed for $f @host($host)"
        fi
        return 1
      fi
    fi
  done
  return 0
}

check_system_init_reqrmnts_met() {
  required_files="/etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.key $HOME/.kube/config"
  check_file_existence $1 $required_files || return 1
}

check_if_etcd_installed() {
  #required_files="/usr/local/bin/etcd /usr/local/bin/etcdctl /etc/systemd/system/etcd.service"
  local required_files="/usr/local/bin/etcd /usr/local/bin/etcdctl"
  #check_file_existence $1 $required_files || return 1
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
    count=$(remote_cmd $1 "ls -l $default_restore_path 2>/dev/null | grep -c ^d  || mkdir -p $default_restore_path")
    if [ $count ] >0 && remote_cmd $1 [ -d $default_restore_path/restore#$((count + 1)) ]; then
      remote_cmd $1 "ls -l $default_restore_path | grep ^d >list.txt"
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
#NG
api_server_etcd_url() {
  _etcd_servers=''
  for ip in $etcd_ips; do
    if can_access_ip $ip; then
      if [ -z $_etcd_servers ]; then
        _etcd_servers=https://$ip:2379
      else
        _etcd_servers+=,https://$ip:2379
      fi
    else
      err "Can not access host($ip) - ignored as etcd server end point!"
    fi
  done
  _etcd_servers=$(echo $_etcd_servers | xargs)
  if [ -z "$_etcd_servers" ]; then
    err "API server etcd endpoints empty"
  else
    export API_SERVER_ETCD_URL=$_etcd_servers
    echo ""
    debug "etcd server url for api server: $API_SERVER_ETCD_URL"
  fi

}
#NG
etcd_initial_cluster() {
  initial_cluster=''
  for svr in $etcd_servers; do
    pair=(${svr//:/ })
    host=${pair[0]}
    ip=${pair[1]}
    if can_access_ip $ip; then
      if [ -z $initial_cluster ]; then
        initial_cluster=$host=https://$ip:2380
      else
        initial_cluster+=,$host=https://$ip:2380
      fi
    else
      err "Could not access host($ip) - was ignored as part of etcd initial cluster"
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
#Might need change if ping is disabled
is_machine_up() {
  ping -Oc 3 $1
  if [ "$?" -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

function postUpMessage() {
  echo -e "\n\033[92m¯\_(ツ)_/¯\033[0m"
}
#kudu's https://stackoverflow.com/questions/12768907/how-can-i-align-the-columns-of-tables-in-bash
#https://github.com/gdbtek/linux-cookbooks/blob/master/libraries/util.bash

function printTable() {
  local -r delimiter="${1}"
  local -r data="$(removeEmptyLines "${2}")"

  if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]; then
    local -r numberOfLines="$(wc -l <<<"${data}")"

    if [[ "${numberOfLines}" -gt '0' ]]; then
      local table=''
      local i=1

      for ((i = 1; i <= "${numberOfLines}"; i = i + 1)); do
        local line=''
        line="$(sed "${i}q;d" <<<"${data}")"

        local numberOfColumns='0'
        numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<<"${line}")"

        # Add Line Delimiter

        if [[ "${i}" -eq '1' ]]; then
          table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
        fi

        # Add Header Or Body

        table="${table}\n"

        local j=1

        for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
          table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<<"${line}")")"
        done

        table="${table}#|\n"

        # Add Line Delimiter

        if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]; then
          table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
        fi
      done

      if [[ "$(isEmptyString "${table}")" = 'false' ]]; then
        echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
      fi
    fi
  fi
}

function removeEmptyLines() {
  local -r content="${1}"
  echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString() {
  local -r string="${1}"
  local -r numberToRepeat="${2}"

  if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
    local -r result="$(printf "%${numberToRepeat}s")"
    echo -e "${result// /${string}}"
  fi
}

function isEmptyString() {
  local -r string="${1}"

  if [[ "$(trimString "${string}")" = '' ]]; then
    echo 'true' && return 0
  fi
  echo 'false' && return 1
}

function trimString() {
  local -r string="${1}"
  sed 's,^[[:blank:]]*,,' <<<"${string}" | sed 's,[[:blank:]]*$,,'
}

api_server_pointing_at() {
  master_pointees=''
  if [ ! -z "$master_address" ]; then
    if [ "$this_host_ip" = "$master_address" ]; then
      master_pointees=$(cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep etcd-servers | cut -d'=' -f2)
    else
      master_pointees=$(remote_cmd $master_address \
        "cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep etcd-servers | cut -d'=' -f2")
    fi
    master_pointees=$(echo $master_pointees | xargs)
    debug "kubernetes master is pointing at: $master_pointees"
    export API_SERVER_POINTING_AT="$master_pointees"
  else
    err "kube master_address not set"
  fi
}

probe_endpoints() {
  api_server_etcd_url
  [ "$#" -gt 0 ] && debug "extra endpoint(s): $@" || debug "No extra endpoint(s) are provided"

  arg_endpoints=''
  if [ "$#" -lt 3 ]; then
    extra_endpoints=$@
  else
    shift
    shift
    extra_endpoints=$@
  fi
  for ep in $extra_endpoints; do
    ep=$(echo $ep | xargs)
    if [ -z $arg_endpoints ]; then
      arg_endpoints=https://$ep:2379
    else
      arg_endpoints+=,https://$ep:2379
    fi
  done

  etcd_server_endpoints=$(echo $API_SERVER_ETCD_URL | xargs)

  endpoints_combined="$arg_endpoints $etcd_server_endpoints"
  endpoints_combined=$(echo $endpoints_combined | tr ',' ' ')
  normalized_endpoints=''

  for entry in $endpoints_combined; do
    if ! [[ "$normalized_endpoints" =~ "$entry" ]]; then
      if [ -z "$normalized_endpoints" ]; then
        normalized_endpoints=$entry
      else
        normalized_endpoints+=" $entry"
      fi
    fi
  done

  if [ -z "$normalized_endpoints" ]; then
    err "Empty end point list" && return 1
  fi

  debug "Endpoints normalized: $normalized_endpoints"
  debug "etcd_server endpoint entries: $etcd_server_endpoints"

  normalized_endpoints=$(echo $normalized_endpoints | tr ' ' ',')
  export PROBE_ENDPOINTS="$normalized_endpoints"
}

embedded_etcd_endpoints() {
  unset EMBEDDED_ETCD_ENDPOINTS
  if [ -z "$masters" ]; then
    err "No master(s) address found. Has the system been initialized?"
    return 1
  else
    unset endpoints
    for mstr in $masters; do
      if [ -z "$endpoints" ]; then
        endpoints=$mstr:2379
      else
        endpoints+=",$mstr:2379"
      fi
    done
    export EMBEDDED_ETCD_ENDPOINTS=$endpoints
    debug "Embedded etcd endpoints: $endpoints"
  fi
}
em_endpoint_list() {
  unset EMBEDDED_ETCD_ENDPOINT
  if ! embedded_etcd_endpoints; then
    return 1
  else
    prnt "Checking embedded cluster endpoins..."
    rm -f /tmp/embedded-etcd-ep-status.txt
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$EMBEDDED_ETCD_ENDPOINTS member list | tee /tmp/embedded-etcd-ep-status.txt
    if [ "$?" -eq 0 ]; then
      end_point=$(cat /tmp/embedded-etcd-ep-status.txt | head -n 1 | cut -d',' -f5 | xargs)
      export EMBEDDED_ETCD_ENDPOINT=$end_point
    else
      err "Etcd member list error"
      return 1
    fi
  fi
}

external_etcd_endpoints() {
  unset EXTERNAL_ETCD_ENDPOINTS
  unset ETCD_INITIAL_CLUSTER
  if [ -z "$etcd_servers" ]; then
    err "No external etcd server(s) found. Has external etcd been setup?"
    return 1
  else
    unset etcd_endpoints
    unset initial_cluster
    for svr in $etcd_servers; do
      host=$(echo $svr | cut -d ':' -f1)
      ip=$(echo $svr | cut -d ':' -f2)
      if [ -z "$etcd_endpoints" ]; then
        etcd_endpoints=$ip:2379
        initial_cluster=$host=https://$ip:2380
      else
        etcd_endpoints+=,$ip:2379
        initial_cluster+=,$host=https://$ip:2380
      fi
    done
    export EXTERNAL_ETCD_ENDPOINTS=$etcd_endpoints
    export ETCD_INITIAL_CLUSTER=$initial_cluster
    debug "etcd initial cluster: $ETCD_INITIAL_CLUSTER"
    debug "External etcd endpoints: $etcd_endpoints"
  fi
}

ex_endpoint_list() {
  if ! external_etcd_endpoints; then
    return 1
  else
    prnt "Checking external cluster endpoints"
    rm -f /tmp/external-etcd-ep-status.txt
    ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/$(hostname)-client.crt \
      --key=/etc/kubernetes/pki/etcd/$(hostname)-client.key \
      --endpoints=$EXTERNAL_ETCD_ENDPOINTS member list | tee /tmp/external-etcd-ep-status.txt
    if [ "$?" -eq 0 ]; then
      end_point=$(cat /tmp/external-etcd-ep-status.txt | head -n 1 | cut -d',' -f5 | xargs)
      export EXTERNAL_ETCD_ENDPOINT=$end_point
    else
      err "Etcd member list error"
      return 1
    fi
  fi
}
