#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage etcd snapshots"
declare -A snapshotActions
snapshotActions+=(['Quit']='quit')
snapshotActions+=(['Refresh view']='refresh-view')
snapshotActions+=(['Save snapshot']='save')
snapshotActions+=(['Delete all or selected snapshots']='delete')
snapshotActions+=(['Restore snapshot']='restore')
snapshotActions+=(['List snapshots']='list')
snapshotActions+=(['State view']='state-view')
snapshotActions+=(['Cluster view']='cluster-view')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select action in "${!snapshotActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 8 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${snapshotActions[$action]}" in
      list)
        list_snapshots
        ;;
      save)
        prnt "Saving snapshot"
        read -p 'Enter file name: ' file_Name
        if [ ! -z $file_Name ]; then
          . save-snapshot.sh $file_Name
        else
          err "Provide a file name!"
        fi
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
          err "No snapshot to delete"
        fi
        ;;
      restore)
        . widgets/select-and-restore-snapshot.sh
        echo ""
        PS3=$'\e[01;32mSelection: \e[0m'
        ;;
      state-view)
        script=$(readlink -f "states.sh")
        exec "$script"
        ;;
      cluster-view)
        script=$(readlink -f "cluster.sh")
        exec "$script"
        ;;
      cluster-state)
        . checks/cluster-state.sh
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
        script=$(readlink -f "$0")
        exec "$script"
        ;;
      quit)
        prnt "quit"
        break
        ;;
      *)
        err "I am not prgrammed to receive you!"
        ;;
    esac
  fi
done

