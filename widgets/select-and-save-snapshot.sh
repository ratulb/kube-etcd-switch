#!/usr/bin/env bash
. utils.sh
PS3=$'\e[92mSaving snapshot - choose cluster: \e[0m'
user_options=('Embedded etcd' 'External etcd' 'Back')
select user_option in "${user_options[@]}"; do
  case "$user_option" in
    'Embedded etcd')
      if em_ep_state_and_list; then
        unset fileName
        while [[ -z "$fileName" ]] && [[ ! "$fileName" = "q" ]]; do
          read -p 'Snapshot name(q - quit): ' fileName
          [ -z "$fileName" ] && err "Snapshot name is needed"
        done
        if [ "$fileName" = "q" ]; then
          prnt "Cancelled snapshot save"
        else
          . save-snapshot.sh $fileName 'embedded'
          break && return 0
        fi
      else
        err "Endpoint status check failed - Unable to save snapshot"
        break && return 1
      fi
      ;;
    'External etcd')
      if ex_ep_state_and_list; then
        unset fileName
        while [[ -z "$fileName" ]] && [[ ! "$fileName" = "q" ]]; do
          read -p 'Snapshot name(q - quit): ' fileName
          [ -z "$fileName" ] && err "Snapshot name is needed"
        done
        if [ "$fileName" = "q" ]; then
          prnt "Cancelled snapshot save"
        else
          . save-snapshot.sh $fileName 'external'
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
