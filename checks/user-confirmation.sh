#!/usr/bin/env bash
read -p "Proceed with the backup?" -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    err "\nAborted backup.\n"
    exit 1
fi
