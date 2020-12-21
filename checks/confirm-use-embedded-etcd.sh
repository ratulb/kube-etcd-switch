#!/usr/bin/env bash
. utils.sh

case $CLUSTER_STATE in
  1000)
    if [ $# = 0 ] || [ $1 != '--force' -a $1 != '-f' ]; then
      err "Already on embedded etcd! $0 --force|-f will restore last good snapshot."
      exit 1
    else
      prnt "Will restore last good snapshot."
    fi
    ;;
  2000)
    prnt "Moving from externa to embedded embedded etcd."
    ;;
  3000 | 4000 | *)
    prnt "Will restore last good snapshot."
    ;;
esac

