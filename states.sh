#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage etcd states"
declare -A stateActions
stateActions+=(['Quit']='quit')
stateActions+=(['Save the current running etcd state']='save')
stateActions+=(['Delete all or selected states']='delete')
stateActions+=(['Restore a saved state']='restore')
stateActions+=(['List the saved states']='list')
stateActions+=(['Restore last external etcd state']='last-external')
stateActions+=(['Restore last embedded etcd state']='last-embedded')
stateActions+=(['System pods states']='pod-state')
stateActions+=(['Current cluster state']='cluster-state')
stateActions+=(['Restart kubernetes runtime']='restart-runtime')
stateActions+=(['Refresh view']='refresh-view')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select option in "${!stateActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 11 -o "$REPLY" -lt 1 ]; then
    err "Invalid snapshot!"
  else
    case "${stateActions[$option]}" in
      list)
        list_saved_states
        ;;
      save)
        prnt "Saving state - enter file name"
        read fileName
        . save-state.sh $fileName
        ;;
      delete)
        if saved_state_exists; then
          PS3="Deleting states - choose option: "
          delete_options=(All Some Done)
          select delete_option in "${delete_options[@]}"; do
            case "$delete_option" in
              All)
                echo "Deleting all saved states"
		delete_saved_states -a
                break
                ;;
              Some)
                echo "Type in file names - blank line to complete"
                rm -f /tmp/state_deletions.tmp
                while read line; do
                  # break if the line is empty
                  [ -z "$line" ] && break
                  echo "$line" >> /tmp/state_deletions.tmp
                done
		selected_for_deletions=$(cat /tmp/state_deletions.tmp | tr "\n" " " | xargs)
                delete_saved_states $selected_for_deletions
		rm -f /tmp/state_deletions.tmp
                break
                ;;
              Done)
		 break
		 ;;
            esac
          done
          echo ""

          PS3=$'\e[01;32mSelection: \e[0m'
        else
          prnt "No saaved state to delete"
        fi
        ;;
      restore)
        prnt "Restoring state - enter state name: "
        read fileName
	if saved_state_exists $fileName; then
      	  . restore-state.sh $fileName 
        fi
        ;;
      last-embedded)
        prnt "Restoring last embedded state"
	. restore-state.sh embedded-up
        ;;
      last-external)
        prnt "Restoring last external state"
	. restore-state.sh external-up
        ;;
	cluster-state)
        prnt "Clsuter state"
        debug=y . cs.sh
        ;;
	pod-state)
        prnt "System pod status"
        . checks/system-pod-state.sh
        ;;
	restart-runtime)
        . restart-runtime.sh
        ;;
	refresh-view)
        . states.sh && exit 0
        ;;
      quit)
        prnt "quit"
        break
        ;;

      *)
        err "The all match case"
        ;;

    esac

  fi

done

'
case $1 in
  -h | --help)
    prnt "$0 -h|--help - prints this help."
    prnt "$0 -l|--list - list the the good states preserved."
    prnt "$0 save -f|--file fileNamme - save the current etcd state/states to the named file if etcd is up."
    prnt "$0 -d|--delete -a|--all|files - delete all or the named state/states."
    prnt "$0 -r|--restore -f|--file fileName - restore the named state or last good saved state."
    prnt "$0 restore-embedded - restore the last embedded etcd saved state."
    prnt "$0 restore-external - restore the last external etcd saved state."
    ;;
  -l | --list)
    list_saved_states
    ;;
  save)
    if [ "$#" -ne 3 -a \( "$2" != '-f' -o "$2" != '--file' \) ]; then
      err "Invalid arguments! See $0 -h|--help"
      exit 1
    fi
    . save-state.sh $3
    ;;
  -d | --delete)
    if [ "$#" -ne 2 ]; then
      err "Invalid arguments! See $0 -h|--help"
      exit 1
    fi
    shift
    delete_saved_states "$@"
    ;;
  -r | --restore)
    if [ "$#" -ne 3 -a \( "$2" != '-f' -o "$2" != '--file' \) ]; then
      err "Invalid arguments! See $0 -h|--help"
      exit 1
    fi
    if saved_state_exists $3; then
      . restore-state.sh $3
    fi
    ;;
  restore-embedded)
    . restore-state.sh embedded-up
    ;;
  restore-external)
    . restore-state.sh external-up
    ;;
  *)
    err "See $0 -h|--help"
    ;;
esac
#'
