#!/usr/bin/env bash
. utils.sh
clear
prnt "Setup single/multi-node cluser(this version allows only single master)"
PS3=$'\e[01;32mChoose option: \e[0m'
setup_options=("Master ip" "Worker ip(s)" "Cancel")
select setup_option in "${setup_options[@]}"; do
  case "$setup_option" in
    "Master ip")
      unset masterIp
      prnt "Cluster master(q - cancel)"
      while [[ -z "$masterIp" ]] || ! is_ip $masterIp; do
        read -p 'master ip: ' masterIp
        [ "$masterIp" = "q" ] && break
      done
      if ! [[ -z "$masterIp" ]] && [ "$masterIp" != "q" ]; then
        prnt "Checking access to $masterIp"
        if can_access_ip $masterIp; then
          echo "master=$masterIp" >./extra/setup-kube-cluster-master.txt
        else
          err "$masterIp is not accesible. Has this machine's ssh key been addded to $masterIp?"
        fi
      fi
      ;;
    "Worker ip(s)")
      echo "Type in worker ips(node:1.1.1.1 format) - blank line to complete"
      echo "For single node cluster workers can be skipped!"
      rm -f /tmp/workers.tmp
      while read line; do
        [ -z "$line" ] && break
        echo "$line" >>/tmp/workers.tmp
      done
      if [ -s /tmp/workers.tmp ]; then
        worker_ips=$(cat /tmp/workers.tmp | tr "\n" " " | xargs)
        echo "$worker_ips"
        unset invalid_workers_ips
        unset valid_worker_ips
        for worker_ip in $worker_ips; do
          if ! is_ip $worker_ip; then
            invalid_worker_ips+="$worker_ip "
          else
            valid_worker_ips+="$worker_ip "
          fi
        done
        echo "valid worker ips: $valid_worker_ips"
        if [ -z $invalid_worker_ips ]; then
          prnt "Checking access to $valid_ips ..."
          unset inaccessibles
          for valid_worker_ip in $valid_worker_ips; do
            if ! can_access_ip $valid_worker_ip; then
              inaccessibles+="$valid_worker_ip "
            fi
          done
          if [[ -z $inaccessibles ]]; then
            echo "workers=$valid_worker_ips" >./extra/setup-kube-cluster-workers.txt
            prnt "Preparing kubenetes installation on $kube_master $valid_ips"
            rm -rf ../k8s-easy-install.backup &>/dev/null
            mv -f ../k8s-easy-install ../k8s-easy-install.backup &>/dev/null
            cd ..
            git clone "$kube_install_git_repo"
            cd - &>/dev/null
            kube_master=$(cat ./extra/setup-kube-cluster-master.txt | grep master | cut -d'=' -f2)
            kube_workers=$(cat ./extra/setup-kube-cluster-workers.txt | grep workers | cut -d'=' -f2)

            sed -i "s/master=.*/master=$kube_master/g" ../k8s-easy-install/setup.conf
            sed -i "s/workers=.*/workers=$kube_workers/g" ../k8s-easy-install/setup.conf
            . checks/confirm-action.sh "Proceed with installtion" "Cancelled"
            if [ "$?" -eq 0 ]; then
              cd ../k8s-easy-install/ &>/dev/null
              ./launch-cluster.sh
              cd - &>/dev/null
              prnt "kubernetes cluster has been installed successfully with master @$kube_master"
            else
              :
            fi
          else
            err "Not able to access $inaccessibles. Has this machine's SSH key been copied to worker nodes?"
            unset inaccessibles
          fi
        else
          err "Invalid workers: $invalid_worker_ips"
          unset invalid_worker_ips
        fi
      else
        PS3=$'\e[01;32mChoose option: \e[0m'
      fi
      ;;
    'Cancel')
      break
      echo ""
      PS3=$'\e[01;32mSelection: \e[0m'
      ;;
    *)
      err "Invalid selection"
      ;;
  esac
done
echo ""
PS3=$'\e[01;32mSelection: \e[0m'
