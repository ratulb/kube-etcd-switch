#!/usr/bin/env bash
#If this host is not part of the cluster
. utils.sh

if [ "$k8s_master" == *"$this_host_ip"* -o "$etcd_servers" == *"$this_host_ip"* ]; then
  exit 0
fi

if ! which kubectl &>/dev/null; then
  curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

mkdir -p ~/.kube/
sudo -u $usr scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $master_ip:~/.kube/config ~/.kube/
chown $(id -u):$(id -g) ~/.kube/config

sed -i '/source <(kubectl completion bash)/d' ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc

