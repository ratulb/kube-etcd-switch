#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage external etcd(mee)"
declare -A extEtcdActions
extEtcdActions+=(['Quit']='quit')
extEtcdActions+=(['Nodes']='nodes')
extEtcdActions+=(['Add node']='add-node')
extEtcdActions+=(['Remove node']='remove-node')
extEtcdActions+=(['Etcd cluster status']='etcd-cluster-status')
extEtcdActions+=(['Start etcd cluster']='start-etcd-cluster')
extEtcdActions+=(['Stop etcd cluster']='stop-cluster-etcd')
extEtcdActions+=(['Refresh view']='refresh-view')
extEtcdActions+=(['Fresh setup']='fresh-setup')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection(mee): \e[0m'
select option in "${!extEtcdActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 9 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${extEtcdActions[$option]}" in
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
            #read_setup
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
          PS3=$'\e[01;32mSelection(mee): \e[0m'
        else
          err "No saaved state to delete"
        fi
        ;;
      etcd-cluster-status)
        . checks/endpoint-liveness-cluster.sh
        ;;
      start-etcd-cluster)
        prnt "Restoring last embedded state"
        . restore-state.sh embedded-up
        ;;
      stop-etcd-cluster)
        prnt "Restoring last external state"
        . restore-state.sh external-up
        ;;
      fresh-setup)
        PS3=$'\e[01;32mFresh setup: \e[0m'
        cat help/ssh-setup.txt
        echo ""
        fresh_setup_options=("Proceed with setup" "Cancel" "Done")
        select fresh_setup_option in "${fresh_setup_options[@]}"; do
          case "$fresh_setup_option" in
            'Proceed with setup')
              if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
                echo "SSH key already exists"
                cat help/copy-ssh-key.txt
              else
                echo "SHH key not present - would need to be generated."
                cat help/ssh-key-gen.txt
                err "ssh-keygen"
              fi
              ;;
            'Cancel')
              prnt "Cancelled setup"
              break
              ;;
            'Done')
              echo "Type in the ip addreses of etcd cluster nodes - blank line to complete"
              rm -f /tmp/cluster-ip-addresses.tmp
              while read line; do
                [ -z "$line" ] && break
                echo "$line" >>/tmp/cluster-ip-addresses.tmp
              done
              ip_addresses=$(cat /tmp/cluster-ip-addresses.tmp | tr "\n" " " | xargs)
              echo $ip_addresses

              if [ -z "$ip_addresses" ]; then
                err "No ip address entered"
              else
                valid_ips=''
                invalid_ips=''
                for ip in $ip_addresses; do
                  if is_ip $ip; then
                    if [ -z "$valid_ips" ]; then
                      valid_ips=$ip
                    else
                      valid_ips+=" $ip"
                    fi
                  else
                    if [ -z "$invalid_ips" ]; then
                      invalid_ips=$ip
                    else
                      invalid_ips+=" $ip"
                    fi
                  fi
                done
                if [[ -z "$invalid_ips" ]] && [[ ! -z "$valid_ips" ]]; then
                  prnt "Checking access to $valid_ips"
                  accessible_ips=''
                  not_accessible_ips=''
                  for valid_ip in $valid_ips; do
                    if can_access_ip $valid_ips; then
                      accessible_ips+=" $valid_ip"
                    else
                      not_accessible_ips+=" $valid_ip"
                    fi
                  done
                  if [ ! -z "$not_accessible_ips" ]; then
                    err "Ips not accessible: $not_accessible_ips"
                    echo "Fix the access issue"
                  else
                    prnt "Going to launch setup for cluster ip(s) - $accessible_ips"
                  fi

                else
                  err "Are the ip(s) correct?"
                  [[ -z $invalid_ips ]] || echo $invalid_ips
                  prnt "Enter again?"
                fi
              fi

              rm -f /tmp/cluster-ip-addresses.tmp
              #break
              ;;

          esac

        done

        PS3=$'\e[01;32mSelection(mee): \e[0m'

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
        PS3=$'\e[01;32mSelection(mee): \e[0m'
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
