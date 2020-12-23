#!/usr/bin/env bash
. utils.sh

case $cluster_state in
  1)
    prnt "Moving from embedded to external etcd."
    ;;
  2)
    if [ $# = 0 ] || [ $1 != '--force' -a $1 != '-f' ]; then
      err "Already on external etcd! $0 --force|-f will restore last snapshot."
      exit 1
    else
      prnt "Will restore last snapshot."
    fi
    ;;
  3 | 4 | *)
    prnt "Will restore last snapshot."
    ;;
esac
