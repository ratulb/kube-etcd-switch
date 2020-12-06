#!/usr/bin/env bash

apt update
apt -y upgrade
if  ! which cfssl &> /dev/null ; then
  apt install golang -y
  go get -u -v github.com/cloudflare/cfssl/cmd/cfssl
  cp ~/go/bin/cfssl /usr/local/bin/cfssl
  go get -u -v github.com/cloudflare/cfssl/cmd/cfssljson
  cp ~/go/bin/cfssljson /usr/local/bin/cfssljson

fi
apt install tree -y
apt autoremove -y
