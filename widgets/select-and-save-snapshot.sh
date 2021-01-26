#!/usr/bin/env bash
. utils.sh
PS3=$'\e[92mSaving snapshot - choose cluster: \e[0m'
user_options=('Embedded etcd' 'External etcd' 'Back')
select user_option in "${user_options[@]}"; do
  case "$user_option" in
    'Embedded etcd')
      . checks/ep-state-embedded.sh
      if [ "$?" -eq 0 ]; then
        unset fileName
        while [[ -z "$fileName" ]] && [[ ! "$fileName" = "q" ]]; do
          read -p 'Snapshot name(q - quit): ' fileName
          [ -z "$fileName" ] && err "Snapshot name is needed"
        done
        if [ "$fileName" = "q" ]; then
          prnt "Cancelled snapshot save"
        else
          . save-snapshot-em.sh $fileName
          break && return 0
        fi
      else
        err "Endpoint status check failed - Unable to save snapshot"
        break && return 1
      fi
      ;;
    'External etcd')
      . checks/ep-state-external.sh
      if [ "$?" -eq 0 ]; then
        unset fileName
        while [[ -z "$fileName" ]] && [[ ! "$fileName" = "q" ]]; do
          read -p 'Snapshot name(q - quit): ' fileName
          [ -z "$fileName" ] && err "Snapshot name is needed"
        done
        if [ "$fileName" = "q" ]; then
          prnt "Cancelled snapshot save"
        else
          . save-snapshot-ex.sh $fileName
          break && return 0
        fi
      else
        err "Endpoint status check failed - Unable to save snapshot"
        break && return 1
      fi
      ;;
    'Back')
      prnt "Exited snapshot save"
      break
      ;;
    *)
      err "Invalid selection"
      ;;
  esac
done
