#!/usr/bin/env bash
. utils.sh
if saved_snapshot_exists; then
  prnt "Clusters:"
  declare -A clusters
  clusters+=([embedded]='embedded-up' [external]='external-up')
  declare -A fileNames
  for file in $default_backup_loc/*.db; do
    fName=$(basename $file)
    fileNames+=([$fName]=$file)
  done
  PS3=$'\e[01;32mChoose cluster(q to quit): \e[0m'
  unset user_cluster
  select cluster in "${!clusters[@]}"; do
    if [ "$cluster" == 'embedded' -o "$cluster" == 'external' ]; then
      prnt "\nCluster chosen $cluster ($REPLY)"
      user_cluster=$cluster
      PS3=$'\e[01;32mChoose snapshot(q to quit) \e[0m'
      re="^[0-9]+$"
      unset user_snapshot
      select fileName in "${!fileNames[@]}"; do
        if [ "$REPLY" == 'q' ]; then
          break
        fi
        if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt "$count" -o "$REPLY" -lt 1 ]; then
          err "Invalid snapshot!"
        else
          echo "Selected $fileName ($REPLY)"
          user_snapshot=$fileName
          break
        fi
      done
      break
    else
      if [ "$REPLY" == 'q' ]; then
        break
      fi
      err "Invalid cluster"
    fi
  done
  unset usr_cluster
  unset usr_snapshot
  if [ \( ! -z "$user_cluster" \) -a  \( ! -z "$user_snapshot" \) ]; then
    usr_cluster="${clusters[$user_cluster]}"
    usr_snapshot="${fileNames[$user_snapshot]}"
    debug "User has selected $usr_cluster and $usr_snapshot."
    . checks/confirm-action.sh "Proceed" "Cancelled snapshot save"
    if [ "$?" -eq 0 ]; then
      [ "$usr_cluster" == 'embedded-up' ] && . restore-snapshot@master.sh "$usr_snapshot"
      [ "$usr_cluster" == 'external-up' ] && . restore-snapshot@nodes.sh "$usr_snapshot"
    fi
  fi
else
  err "No snapshot found to restore!"
fi
