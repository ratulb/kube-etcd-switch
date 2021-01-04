#!/usr/bin/env bash
. utils.sh
clear
prnt "Setup single/multi-node cluser(this version allows only single master)"
PS3=$'\e[01;32mChoose option: \e[0m'
setup_options=("Enter master name & ip" "Enter worker name(s) & ip(s)" "Proceed" "Cancel")
select setup_option in "${setup_options[@]}"; do
  case "$setup_option" in
    "Enter master name & ip")
      unset masterName
      unset masterIp
      prnt "Cluster master(q - cancel)"
      while [ -z "$masterName" ]; do
        read -p 'maaster name: ' masterName
        [ "$masterName" = "q" ] && break
      done
      if [ "$masterName" != "q" ]; then
        while [[ -z "$masterIp" ]] || ! is_ip $masterIp; do
          read -p 'master ip: ' masterIp
          [ "$masterIp" = "q" ] && break
        done
      fi
      if ! [[ -z "$masterIp" ]] && [ "$masterIp" != "q" ]; then
        prnt "Checking access to $masterIp..."
        if can_access_ip $masterIp; then
          prnt "Saving master ip..."
          echo "master=$masterIp" >./extra/setup-kube-cluster.txt
          echo "master_name=$masterName" >>./extra/setup-kube-cluster.txt
        else
          err "$masterIp is not accesible. Has this machine's ssh key been addded to $masterIp?"
        fi
      fi
      ;;
    "Enter worker name(s) & ip(s)")
      echo "Type in worker names and ips(node:1.1.1.1 format) - blank line to complete"
      rm -f /tmp/workers.tmp
      while read line; do
        [ -z "$line" ] && break
        echo "$line" >>/tmp/workers.tmp
      done
      if [ -s /tmp/workers.tmp ]; then
        workers=$(cat /tmp/workers.tmp | tr "\n" " " | xargs)
        echo "$workers"
        invalid_workers=''
        valid_ips=''
        for worker in $workers; do
          host_part=$(echo $worker | cut -d':' -f1)
          ip_part=$(echo $worker | cut -d':' -f2)
          if ! is_host_name_ok $host_part || ! is_ip $ip_part; then
            invalid_workers+="$worker "
          else
            valid_ips+="$ip_part "
          fi
        done
        if [ -z $invalid_workers ]; then
          prnt "Entries are good $workers"
          prnt "Checking access to $valid_ips ..."
          inaccessibles=''
          for valid_ip in $valid_ips; do
            if ! can_access_ip $valid_ip; then
              inaccessibles+="$valid_ip "
            fi
          done
          if [ -z $inaccessibles ]; then
            prnt "Workers ip(s) accessible"
            echo "workers=$valid_ips" >>./extra/setup-kube-cluster.txt
            kube_master=$(cat ./extra/setup-kube-cluster.txt | grep master | cut -d'=' -f1)
            prnt "Preparing kubenetes installation on $kube_master $valid_ips"
            mv -f ../k8s-easy-install ../k8s-easy-install.backup &>/dev/null
            echo "$kube_install_git_repo $kube_install_git_repo"
            echo "Current folder $(pwd)"
            cd ..
            git clone "$kube_install_git_repo"

            old_master_in_repo=$(cat ./k8s-easy-install/setup.conf | grep master | cut -d'=' -f2 | xargs)
	    echo "old_master_in_repo: $old_master_in_repo"
            old_workers_in_repo=$(cat ./k8s-easy-install/setup.conf | grep workers | cut -d'=' -f2 | xargs)
	    echo "old_workers_in_repo: $old_workers_in_repo  $kube_master  $valid_ips"
            sed -i "s|$old_master_in_repo|$kube_master|g" ./k8s-easy-install/setup.conf
            sed -i "s|$old_workers_in_repo|$valid_ips|g" ./k8s-easy-install/setup.conf
	    exit 0
            cd -
            . checks/confirm-action.sh "Proceed with installtion" "Cancelled"
            if [ "$?" -eq 0 ]; then
              cd ../k8s-easy-install/
              ./launch-cluster.sh
              cd - &>/dev/null
              prnt "kubernetes cluster has been installed successfully with master @$kube_master"
            else
              :
            fi
          else
            err "Not able to access $inaccessibles. Has this machine's SSH key been copied to worker nodes?"
          fi
        else
          err "Invalid workers: $invalid_workers"
        fi
      else
        err "None selected!"
      fi
      break
      ;;
    "Proceed")
      break
      ;;
    "Cancel")
      break
      ;;
    *)
      echo "$setup_option $setup_option $setup_option"
      err "Invalid selection"
      ;;
  esac
done
echo ""
PS3=$'\e[01;32mSelection: \e[0m'
