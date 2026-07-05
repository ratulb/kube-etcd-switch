#!/usr/bin/env bash
. utils.sh

prnt "Installing cloudflare cfssl"

download_url=https://github.com/cloudflare/cfssl/releases/download
ver=1.4.1
if ! which cfssl &>/dev/null; then
  sudo curl -sL ${download_url}/v${ver}/cfssl_${ver}_linux_amd64 -o /usr/local/bin/cfssl
  sudo chmod +x /usr/local/bin/cfssl
  sudo curl -sL ${download_url}/v${ver}/cfssljson_${ver}_linux_amd64 -o /usr/local/bin/cfssljson
  sudo chmod +x /usr/local/bin/cfssljson
  sudo curl -sL ${download_url}/v${ver}/cfssl-certinfo_${ver}_linux_amd64 -o /usr/local/bin/cfssl-certinfo
  sudo chmod +x /usr/local/bin/cfssl-certinfo
else
  prnt "Cloudflare cfssl is already installed"
fi
