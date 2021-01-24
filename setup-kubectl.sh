#!/usr/bin/env bash
#If this host is not part of the cluster
. utils.sh

if [ "$#" -ne 1 ]; then
  warn "Usage: ./setup-kubectl.sh  'master address'"
  return 1
fi
m_address=$1
read_setup

if [ "$masters" = *"$this_host_ip"* -o "$masters" == *"$this_host_name"* ]; then
  prnt "This host is already part of the cluster($masters) - not setting up kubectl"
  return 0
fi

if ! which kubectl &>/dev/null; then
  curl -sLO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

mkdir -p ~/.kube/
remote_copy $m_address:~/.kube/config ~/.kube/ 2>/dev/null
if [ "$?" -ne 0 ]; then
  err "Could not copy kube config from $m_address - Is it a cluster master member?"
  return 1
fi
chown $(id -u):$(id -g) ~/.kube/config

sed -i '/source <(kubectl completion bash)/d' ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
