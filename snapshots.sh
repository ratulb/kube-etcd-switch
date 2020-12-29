#!/usr/bin/env bash
. utils.sh

case $1 in
  -h | --help)
    prnt "$0 -h|--help - prints this help."
    prnt "$0 -l|--list - list the saved snapshots."
    prnt "$0 save fileNamme - save the current state of the etcd db."
    prnt "$0 -d|--delete -a|--all|files - delete all or the named snapshots."
    prnt "$0 -r|--restore snapshot fileName, -c|--cluster - clsuter name embedded-up|external-up"
    ;;
  -l | --list)
    list_snapshots
    ;;
  save)
    if [ "$#" -eq 2 ]; then
      . save-snapshot.sh $2
    else
      shift
      . save-snapshot.sh
    fi
    ;;
  -d | --delete)
    if [ "$#" -ne 2 ]; then
      err "Invalid arguments! See $0 -h|--help"
    fi
    shift
    delete_snapshots "$@"
    ;;
  -r | --restore)
    if [ "$#" -eq 4 -a \( "$3" == '-c' -o "$3" == '--cluster' \) -a \( "$4" == 'embedded-up' -o "$4" == 'external-up' \) ]; then
      if [ -z "$2" ]; then
        err "Invalid snapshot"
        exit 1
      else
        snapshot=$(basename $2)
        snapshot=$(echo $snapshot | cut -d'.' -f1)
        snapshot=$default_backup_loc/$snapshot.db
      fi
      if [ "$4" == 'embedded-up' ]; then
        . restore-snapshot@master.sh $snapshot
      fi
      if [ "$4" == 'external-up' ]; then
        . restore-snapshot@nodes.sh $snapshot
      fi
    fi
    if [ "$#" -eq 1 ]; then
      . etc/select-snapshots.sh
      cluster="${clusters[$user_cluster]}"
      snapshot="${fileNames[$user_snapshot]}"
     debug "User has selected ${clusters[$user_cluster]} and ${fileNames[$user_snapshot]}."
     [ "$cluster" == 'embedded-up' ] &&  . restore-snapshot@master.sh "$snapshot"
     [ "$cluster" == 'external-up' ] &&  . restore-snapshot@nodes.sh "$snapshot" 
    fi
    ;;
  *)
    err "See $0 -h|--help"
    ;;
esac
