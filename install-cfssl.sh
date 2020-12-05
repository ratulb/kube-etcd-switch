#!/usr/bin/env bash

apt update

wget -q --timestamping https://golang.org/dl/go1.15.5.linux-amd64.tar.gz -O /tmp/go1.15.5.linux-amd64.tar.gz
tar -C /usr/local -xzf /tmp/go1.15.5.linux-amd64.tar.gz

echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin
if ! type gcc > /dev/null 2>&1; then
  apt-get install build-essential -y
fi

go get -u github.com/cloudflare/cfssl/cmd/cfssl
go get -u github.com/cloudflare/cfssl/cmd/cfssljson

apt install tree -y
