#!/usr/bin/env bash
. utils.sh
clear
echo ""
prnt "Manage external etcd(mee)"
declare -A extEtcdActions
extEtcdActions+=(['Quit']='quit')
extEtcdActions+=(['Nodes']='nodes')
extEtcdActions+=(['Add node']='add-node')
extEtcdActions+=(['Remove node']='remove-node')
extEtcdActions+=(['Etcd cluster status']='etcd-cluster-status')
extEtcdActions+=(['Start etcd cluster']='start-etcd-cluster')
extEtcdActions+=(['Stop etcd cluster']='stop-etcd-cluster')
extEtcdActions+=(['Refresh view']='refresh-view')
extEtcdActions+=(['Fresh setup']='fresh-setup')
extEtcdActions+=(['Cluster view']='cluster-view')
extEtcdActions+=(['Probe endpoints']='probe-endpoints')
re="^[0-9]+$"
PS3=$'\e[92mSelection(mee): \e[0m'
select option in "${!extEtcdActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 11 -o "$REPLY" -lt 1 ]; then
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
          . checks/confirm-action.sh "Are they correct(y)" "Cancelled etcd node probe"
          if [ "$?" -eq 0 ]; then
            headers='Host,IP,Accessible,Status'
            echo ""
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
              if can_ping_address $ip; then
                state='Up'
              fi
              node_info=$host,$ip,$access,$state
              echo $node_info >>/tmp/temp_file
              printTable "," "$(cat /tmp/temp_file)"
              echo ""
            done
            printTable "," "$(cat /tmp/temp_file)"
            rm -f /tmp/temp_file
          else
            :
          fi
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
          if [ "$nodeIp" = "127.0.0.1" ]; then
            err "loopback ip not allowed"
          else
            prnt "Checking access to $nodeIp..."
            if can_access_ip $nodeIp; then
              prnt "Adding node $nodeName($nodeIp)"
              . admit-etcd-cluster-node.sh $nodeName $nodeIp
              if [ "$?" -eq 0 ]; then
                prnt "Updating etcd server configuration"
                node_being_added=$nodeName:$nodeIp
                upsert_etcd_server_list $node_being_added
                prnt "Node($nodeIp) has been added"
                . synch-etcd-endpoints.sh
              else
                err "Failed to add node($nodeIp)"
              fi
            else
              err "$nodeIp is not accesible. Has this machine's ssh key been addded to $nodeIp?"
            fi
          fi
        fi
        ;;
      probe-endpoints)
        probe_response=$(. checks/endpoint-probe.sh | sed '/^[[:space:]]*$/d')
        echo "$probe_response"
        ;;
      remove-node)
        prnt "Remove nodes"
        read_setup
        if [ ! -z "$etcd_servers" ]; then
          PS3=$'\e[92mChoose one(q to quit): \e[0m'
          unset etcdHostAndIps
          declare -a etcdHostAndIps
          for etcd_node_entry in $etcd_servers; do
            etcdHostAndIps+=($etcd_node_entry)
          done
          count=${#etcdHostAndIps[@]}
          select host_and_ip in "${etcdHostAndIps[@]}"; do
            if [ "$REPLY" == 'q' ]; then
              PS3=$'\e[92mSelection(mee): \e[0m'
              break
            fi
            if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt "$count" -o "$REPLY" -lt 1 ]; then
              err "Invalid selection"
            else
              echo "Selected $host_and_ip ($REPLY) for removal"
              echo "Removing etcd node: $host_and_ip"
              . remove-admitted-node.sh $host_and_ip
              if [ "$?" -eq 0 ]; then
                prnt "Removed etcd node($host_and_ip) - updating configuration"
                prune_etcd_server_list $host_and_ip
                read_setup
                . synch-etcd-endpoints.sh
                sleep 10
                script=$(readlink -f "$0")
                exec "$script"
              else
                err "Failed to remove etcd node($host_and_ip)"
              fi
            fi
          done
        else
          err "No etcd node to delete"
        fi
        PS3=$'\e[92mSelection(mee): \e[0m'
        ;;
      etcd-cluster-status)
        . checks/endpoint-liveness-cluster.sh
        ;;
      start-etcd-cluster)
        prnt "Starting etcd cluster"
        . start-external-etcds.sh
        ;;
      stop-etcd-cluster)
        prnt "Stopping etcd cluster"
        #print out where they are getting stopped
        . stop-external-etcds.sh
        ;;
      fresh-setup)
        PS3=$'\e[92mFresh setup: \e[0m'
        #cat help/ssh-setup.txt
        #echo ""
        fresh_setup_options=('Launch' 'Back')
        select fresh_setup_option in "${fresh_setup_options[@]}"; do
          case "$fresh_setup_option" in
            'Start')
              if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
                prnt "SSH key already exists"
                cat help/copy-ssh-key.txt
              else
                err "SHH key not present - would need to be generated."
                cat help/ssh-key-gen.txt
                err "ssh-keygen"
              fi
              ;;
            'Back')
              prnt "Exited etcd cluster setup"
              PS3=$'\e[92mSelection(mee): \e[0m'
              echo ""
              break
              ;;
            'Launch')
              echo "Type in the host & ip(s)of etcd cluster nodes - blank line to complete"
              prnt "Example: '$(hostname):$(hostname -i)'"
              rm -f /tmp/etcd_host_and_ips.tmp
              while read line; do
                [ -z "$line" ] && break
                echo "$line" >>/tmp/etcd_host_and_ips.tmp
              done
              unset etcd_host_and_ips
              if [ -s /tmp/etcd_host_and_ips.tmp ]; then
                etcd_host_and_ips=$(cat /tmp/etcd_host_and_ips.tmp | tr "\n" " " | xargs)
              fi
              if [ -z "$etcd_host_and_ips" ]; then
                err "No address entered"
              else
                unset valid_ips
                unset invalid_host_or_ips
                for etcd_host_and_ip in $etcd_host_and_ips; do
                  ip_part=$(echo $etcd_host_and_ip | cut -d':' -f2)
                  host_part=$(echo $etcd_host_and_ip | cut -d':' -f1)
                  if ! is_ip $ip_part || ! is_host_name_ok $host_part; then
                    if [ -z "$invalid_host_or_ips" ]; then
                      invalid_host_or_ips=$etcd_host_and_ip
                    else
                      invalid_host_or_ips+=" $etcd_host_and_ip"
                    fi
                  else
                    if [ -z "$valid_ips" ]; then
                      valid_ips=$ip_part
                    else
                      valid_ips+=" $ip_part"
                    fi
                  fi
                done
                if [[ -z "$invalid_host_or_ips" ]] && [[ ! -z "$valid_ips" ]]; then
                  prnt "Checking access to $valid_ips"
                  not_accessible_ips=''
                  for valid_ip in $valid_ips; do
                    if ! can_access_ip $valid_ip; then
                      not_accessible_ips+=" $valid_ip"
                    fi
                  done
                  if [ -z "$not_accessible_ips" ]; then
                    prnt "Launching cluster for $etcd_host_and_ips"
                    . setup-etcd-cluster.sh "$etcd_host_and_ips"
                    if [ "$?" -eq 0 ]; then
                      prnt "Successfully setup etcd cluster on $valid_ips"
                    else
                      err "Cluster setup failed" && return 1
                    fi
                  else
                    err "Ip(s) not accessible: $not_accessible_ips"
                  fi

                else
                  err "Incorrect host(s) or ip(s)"
                  [[ ! -z $invalid_host_or_ips ]] && echo $invalid_host_or_ips
                fi
              fi

              rm -f /tmp/etcd_host_and_ips.tmp
              #break
              ;;
          esac
        done
        #PS3=$'\e[92mSelection(mee): \e[0m'
        ;;

      refresh-view)
        script=$(readlink -f "$0")
        exec "$script"
        ;;
      quit)
        prnt "quit"
        break 1
        ;;
      cluster-view)
        script=$(readlink -f "cluster.sh")
        exec "$script"
        ;;
      *)
        echo "$option - The option has been disabled"
        ;;
    esac
  fi
done
