#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage etcd cluster"
declare -A clusterActions
clusterActions+=(['Quit']='quit')
clusterActions+=(['System pods states']='pod-state')
clusterActions+=(['Current cluster state']='cluster-state')
clusterActions+=(['Restart kubernetes runtime']='restart-runtime')
clusterActions+=(['Refresh view']='refresh-view')
clusterActions+=(['Snapshot view']='snapshot-view')
clusterActions+=(['State view']='state-view')
clusterActions+=(['System init']='system-init')
clusterActions+=(['External etcd']='external-etcd')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select option in "${!clusterActions[@]}"; do
  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 9 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${clusterActions[$option]}" in
      cluster-state)
        . checks/cluster-state.sh
        ;;
external-etcd)
        echo "External etcd"
        . widgets/external-etcd.sh
        ;;
system-init)
        . widgets/system-init.sh
        echo ""
        PS3=$'\e[01;32mSelection: \e[0m'
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
              if [ -s /tmp/kube_ips.tmp ]; then
              kube_ips=$(cat /tmp/kube_ips.tmp | tr "\n" " " | xargs)
              . restart-runtime.sh $kube_ips
              rm -f /tmp/kube_ips.tmp
              else
                err "No node ips provided!"
              fi
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
      snapshot-view)
        script=$(readlink -f "snapshots.sh")
        exec "$script"
        ;;
      quit)
        prnt "quit"
        break
        ;;
      state-view)
        script=$(readlink -f "states.sh")
        exec "$script"
        ;;
    esac
  fi
done
