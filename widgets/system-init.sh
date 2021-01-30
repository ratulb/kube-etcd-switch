#!/usr/bin/env bash
. utils.sh
initialize() {
  prnt "Checking whether initalization requirements are met..."
  local m_addr=$1
  debug "initialize(): $m_addr"
  if check_system_init_reqrmnts_met $m_addr; then
    prnt "Requirements are satisfied - proceeding with initialization"
    . system-init.sh $m_addr
  else
    err "Requirements are not satified"
    return 1
  fi
}
re="^[0-9]+$"
unset choices
if is_master_set; then
  prnt "Master address: $master_address"
  PS3=$'\e[92mSelect(q to quit): \e[0m'
  choices=('Initialize system' 'Edit master address and initialize')
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
          if can_access_address $master_address; then
            prnt "Initalizing system..."
            initialize $master_address
            if [ "$?" -eq 0 ]; then
              #prnt "System has been initialized successfully"
              read_setup
            else
              err "System initialization failed"
            fi
          else
            err "Can not access $master_address. Has this machine's ssh key been copied to $master_address?"
          fi
          #break
          ;;
        'Edit master address and initialize')
          echo "Edit master address: "
          unset address
          prnt "Master address(q - cancel)"
          while [[ -z "$address" ]] || (! is_ip $address && ! is_host_name_ok $address); do
            read -p 'Master address: ' address
            [ "$address" = "q" ] && break
          done

          if can_access_address $address; then
            prnt "Initalizing system..."
            initialize $address
            if [ "$?" -eq 0 ]; then
              #prnt "System has been initialized successfully"
              read_setup
            else
              err "System initialization failed"
            fi
          else
            err "Can not access $address. Has this machine's ssh key been copied to $address?"
          fi
          #break
          ;;
      esac
    fi
  done
else
  prnt "System initialization - Enter  master address"
  unset address
  read -p 'Master address ' address
  if can_access_address $address; then
    prnt "Initalizing system..."
    initialize $address
    if [ "$?" -eq 0 ]; then
      #prnt "System has been initialized successfully"
      read_setup
    else
      err "System initialization failed"
    fi
  else
    err "System not initialized - master address issue"
  fi
fi
