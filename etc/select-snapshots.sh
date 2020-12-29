#!/usr/bin/env bash
. utils.sh
count=$(find $default_backup_loc/*.db -maxdepth 0 -type f 2>/dev/null | wc -l)
if [ "$count" -gt 0 ]; then
  prnt "Clusters:"
  declare -A clusters
  clusters+=([embedded]='embedded-up' [external]='external-up')
  declare -A fileNames
  for file in $default_backup_loc/*.db; do
    fName=$(basename $file)
    fileNames+=([$fName]=$file)
  done
  PS3="Choose cluster: "
  select cluster in "${!clusters[@]}"; do
    if [ "$cluster" == 'embedded' -o "$cluster" == 'external' ]; then
      re="^[0-9]+$"
      prnt "\nCluster chosen $cluster ($REPLY)"
      user_cluster=$cluster
      PS3="Available snapshots - choose snapshot "
      select fileName in "${!fileNames[@]}"; do
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
      err "Invalid cluster"
    fi
  done
  debug "User has selected ${clusters[$user_cluster]} and ${fileNames[$user_snapshot]}."
else
  err "No snapshot found to restore!"
fi
