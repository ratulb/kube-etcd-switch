#!/usr/bin/env bash
. utils.sh

case $cluster_state in
  embedded-up)
    prnt "Moving from embedded to external etcd."
    ;;
  external-up)
    if [ $# = 0 ] || [ $1 != '--force' -a $1 != '-f' ]; then
      err "Already on external etcd! $0 --force|-f will restore last snapshot."
      exit 1
    else
      prnt "Will restore last snapshot."
    fi
    ;;
  emdown | ukdown | *)
    prnt "Will restore last snapshot."
    ;;
esac
