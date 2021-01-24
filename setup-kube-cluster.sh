#!/usr/bin/env bash
. utils.sh
clear
prnt "Moving to cluster setup"
if [ -d ../k8s-easy-install/ ]; then
  cd ../k8s-easy-install/ && ./cluster.sh
else
  _branch=$(git branch | grep '*' | cut -d' ' -f2)
  rm -rf ../k8s-easy-install.backup &>/dev/null
  mv -f ../k8s-easy-install ../k8s-easy-install.backup &>/dev/null
  cd ..
  git clone "$kube_install_git_repo" -b $_branch &>/dev/null
  cd - &>/dev/null
  cd ../k8s-easy-install/ && ./cluster.sh
fi
cd - &>/dev/null
