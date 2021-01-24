#!/usr/bin/env bash
. utils.sh
initialize() {
  prnt "Checking whether initalization requirements are met..."
  local address=$1
  if check_system_init_reqrmnts_met $address; then
    prnt "Requirements are satisfied"
    . checks/confirm-action.sh "Proceed with initialization(y)" "Cancelled"
    if [ "$?" -eq 0 ]; then
      echo ""
      . system-init.sh $address
    else
      echo "No"
      return 1
    fi
  else
    err "Requirements are not satified"
    return 1
  fi
}
re="^[0-9]+$"
unset choices
if is_master_set; then
  prnt "Master ip: $master_ip"
  PS3=$'\e[01;32mSelect(q to quit): \e[0m'
  choices=('Initialize system' 'Edit master address')
  unset user_action
  select choice in "${choices[@]}"; do
    if [ "$REPLY" == 'q' ]; then
      user_action='q'
      break
    elif ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 2 -o "$REPLY" -lt 1 ]; then
      err "Invalid selection!"
    else
      case "$choice" in
        'Initialize system')
          echo "Initializing system..."
          if can_access_ip $master_ip; then
            prnt "Checking configurations @$master_ip"
            if check_system_init_reqrmnts_met $master_ip; then
              prnt "System configuration checks passed."
              . checks/confirm-action.sh "Proceed(y)" "Cancelled system init"
              if [ "$?" -eq 0 ]; then
                . system-init.sh
                if [ "$?" -ne 0 ]; then
                  err "System initialization is not complete!"
                  return 1
                else
                  break
                fi
              fi
            else
              err "System configuration check @$master_ip failed!"
              return 1
            fi
          else
            err "Can not access $master_ip. Has this machine's ssh key been copied to $master_ip?"
          fi
          #break
          ;;
        'Edit master address')
          echo "Edit master ip: "
          unset address
          prnt "Master ip(q - cancel)"
          while [[ -z "$address" ]] || ! is_ip $address; do
            read -p 'master ip: ' address
            [ "$address" = "q" ] && break
          done

          prnt "Checking access to $address"
          if can_access_ip $address; then
            k8s_master_addr=k8s_master=$address
            if [ ! -z "$debug" ]; then
              cat setup.conf
              sed -i "s/k8s_master=.*/$k8s_master_addr/g" setup.conf
              cat setup.conf
            else
              sed -i "s/k8s_master=.*/$k8s_master_addr/g" setup.conf
            fi
            prnt "Master ip has been updated"
            read_setup
          else
            err "Can not access $address. Has this machine's ssh key been copied to $address?"
          fi
          #break
          ;;
      esac
    fi
  done
else
  prnt "Cluster master address"
  unset address
  read -p 'Master address ' address
  if can_access_address $address; then
    set_master_address $address
    initialize $address
    prnt "Master address has been updated"
    read_setup
  else
    err "Master address not updated"
  fi
fi
