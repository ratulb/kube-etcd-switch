#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage external etcd"
declare -A stateActions
stateActions+=(['Quit']='quit')
stateActions+=(['Nodes']='nodes')
stateActions+=(['Add node']='add-node')
stateActions+=(['Remove node']='remove-node')
stateActions+=(['Cluster etcd status']='cluster-etcd-status')
stateActions+=(['Start cluster etcd']='start-cluster-etcd')
stateActions+=(['Stop cluster etcd']='stop-cluster-etcd')
stateActions+=(['Refresh view']='refresh-view')
stateActions+=(['Run setup']='run-setup')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select option in "${!stateActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 9 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${stateActions[$option]}" in
      nodes)
        prnt "Nodes"
        read_setup
        if [ -z "$etcd_servers" ]; then
          err "No etcd node found"
        else
          prnt "Configured etcd servers: $etcd_ips"
          headers='Host,IP,Accessible,Status'
          echo $headers >/tmp/temp_file
          for svr in $etcd_servers; do
            pair=(${svr//:/ })
            host=${pair[0]}
            ip=${pair[1]}
            access='No'
            if can_access_ip $ip; then
              access='yes'
            fi
            state='N/A'
            if is_machine_up $ip; then
              state='Up'
            fi
            node_info=$host,$ip,$access,$state
            echo $node_info >>/tmp/temp_file
            printTable "," "$(cat /tmp/temp_file)"
            echo ""
          done
          printTable "," "$(cat /tmp/temp_file)"
          rm -f /tmp/temp_file
        fi
        ;;
      add-node)
        unset nodeName
        unset nodeIp
        prnt "Adding etcd node(q - cancel)"
        while [ -z "$nodeName" ]; do
          read -p 'Node name: ' nodeName
          [ "$nodeName" = "q" ] && break
        done
        if [ "$nodeName" != "q" ]; then
          while [[ -z "$nodeIp" ]] || ! is_ip $nodeIp; do
            read -p 'Node ip: ' nodeIp
            [ "$nodeIp" = "q" ] && break
          done
        fi
        if ! [[ -z "$nodeIp" ]] && [ "$nodeIp" != "q" ]; then
          prnt "Checking access to $nodeIp..."
          if can_access_ip $nodeIp; then
            prnt "Setting up etcd on $nodeName($nodeIp)"
            . setup-etcd@node.sh $nodeName $nodeIp
            prnt "Updating etcd server configuration"
            node_being_added=$nodeName:$nodeIp
            upsert_etcd_servers $node_being_added
            read_setup
          else
            err "$nodeIp is not accesible. Has this machine's ssh key been addded to $nodeIp?"
          fi
        fi
        ;;

      remove-node)
        echo "Remove nodes"
        if saved_state_exists; then
          PS3="Deleting states - choose option: "
          delete_options=(All Some Back)
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
                  [ -z "$line" ] && break
                  echo "$line" >>/tmp/state_deletions.tmp
                done
                selected_for_deletions=$(cat /tmp/state_deletions.tmp | tr "\n" " " | xargs)
                delete_saved_states $selected_for_deletions
                rm -f /tmp/state_deletions.tmp
                break
                ;;
              Back)
                break
                ;;
            esac
          done
          echo ""
          PS3=$'\e[01;32mSelection: \e[0m'
        else
          err "No saaved state to delete"
        fi
        ;;
      cluster-etcd-status)
        if saved_state_exists; then
          prnt "Restoring state - enter state name: "
          read fileName
          if saved_state_exists $fileName; then
            . restore-state.sh $fileName
          fi
        else
          err "No saved state to restore!"
        fi
        ;;
      start-cluster-etcd)
        prnt "Restoring last embedded state"
        . restore-state.sh embedded-up
        ;;
      stop-cluster-etcd)
        prnt "Restoring last external state"
        . restore-state.sh external-up
        ;;
      run-setup)
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
      snapshot-view)
        script=$(readlink -f "snapshots.sh")
        exec "$script"
        ;;
      quit)
        prnt "quit"
        break
        ;;
      cluster-view)
        script=$(readlink -f "cluster.sh")
        exec "$script"
        ;;
    esac
  fi
done
