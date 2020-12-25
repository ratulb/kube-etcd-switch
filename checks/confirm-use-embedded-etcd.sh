#!/usr/bin/env bash
. utils.sh

case $cluster_state in
  embedded-up)
    if [ $# = 0 ] || [ $1 != '--force' -a $1 != '-f' ]; then
      err "Already on embedded etcd! $0 --force|-f will restore last snapshot."
      exit 1
    else
      prnt "Will restore last snapshot."
    fi
    ;;
  external-up)
    prnt "Moving from external to embedded etcd."
    #. resurrect-embedded-etcd.sh
    ;;
  emdown | ukdown | *)
    prnt "Will restore last snapshot."
    ;;
esac
