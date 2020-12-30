#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage etcd states"
declare -A actions
actions+=(['Quit']='quit')
actions+=(['Refresh view']='refresh-view')
actions+=(['Restart kubernetes runtime']='restart-runtime')
actions+=(['Current cluster state']='cluster-state')
actions+=(['System pods states']='pod-state')

actions+=(['Save snapshot']='save')
actions+=(['Delete all or selected snapshots']='delete')
actions+=(['Restore snapshot']='restore')
actions+=(['List snapshots']='list')
actions+=(['State view']='state-view')
actions+=(['Cluster view']='cluster-view')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select action in "${!actions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 11 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${actions[$action]}" in
      list)
        list_snapshots
        ;;
      save)
        prnt "Saving snapshot - enter file name"
        read fileName
        . save-snapshot.sh $fileName
        ;;
      delete)
        if saved_snapshot_exists; then
          PS3="Deleting snapshot - choose option: "
          delete_options=(All Some Back)
          select delete_option in "${delete_options[@]}"; do
            case "$delete_option" in
              All)
                echo "Deleting all snapshots"
                delete_snapshots -a
                break
                ;;
              Some)
                echo "Type in file names - blank line to complete"
                rm -f /tmp/snapshot_deletions.tmp
                while read line; do
                  [ -z "$line" ] && break
                  echo "$line" >>/tmp/snapshot_deletions.tmp
                done
                if [ -s /tmp/snapshot_deletions.tmp ]; then
                  selected_for_deletions=$(cat /tmp/snapshot_deletions.tmp | tr "\n" " " | xargs)
                  delete_snapshots $selected_for_deletions
                  rm -f /tmp/snapshot_deletions.tmp
                else
                  err "None selected!"
                fi
                break
                ;;
              Back)
                break
                ;;
	      *) 
	       err "Invalid selection"
 		;;	       
            esac
          done
          echo ""
          PS3=$'\e[01;32mSelection: \e[0m'
        else
          prnt "No snapshot to delete"
        fi
        ;;
      restore)
        . widgets/select-and-restore-snapshot.sh
        echo ""
        PS3=$'\e[01;32mSelection: \e[0m'
        ;;
      state-view)
        . states.sh && exit 0
        ;;
      cluster-view)
        prnt "Cluster view is not ready"
        ;;
      cluster-state)
        . cs.sh
        ;;
      pod-state)
        . checks/system-pod-state.sh
        ;;
      restart-runtime)
        PS3=$'\e[01;32mRestarting k8s runtime - choose option: \e[0m'
        restart_options=("Auto-detect kube nodes" "Enter ips" "Back")
        select restart_option in "${restart_options[@]}"; do
          case "$REPLY" in
            1)
              . restart-runtime.sh
              break
              ;;
            2)
              echo "Type in the kube node IPs - blank line to complete: "
              rm -f /tmp/kube_ips.tmp
              while read line; do
                [ -z "$line" ] && break
                echo "$line" >>/tmp/kube_ips.tmp
              done
              kube_ips=$(cat /tmp/kube_ips.tmp | tr "\n" " " | xargs)
              . restart-runtime.sh $kube_ips
              rm -f /tmp/kube_ips.tmp
              break
              ;;
            3)
              break
              ;;
          esac
        done
        echo ""
        PS3=$'\e[01;32mSelection: \e[0m'
        ;;
      refresh-view)
        . snapshots.sh && exit 0
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
