#!/usr/bin/env bash
. utils.sh
err_msg="Kube vault directory and required atrifacts are missing! Has the system been initialized?"
( [[ -d "$kube_vault" ]] && [[ -d "$gendir" ]] ) || ( err "$err_msg 1" && return 1 )

