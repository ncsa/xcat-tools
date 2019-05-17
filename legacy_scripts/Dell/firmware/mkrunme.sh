#!/bin/bash

# Given a firmware directory name
# Build a runme.sh that 
#   + runs each BIN in succession
#   + saves all output to a known log filename (ie: timestamp.log)
#       - idea is to be able to monitor progress 
#       - by tailing the log from all nodes using xdsh, so something like
#       - xdsh <NODELIST> 'ls -t /root/<firmwaredir>/*.log | tail -1 | xargs tail -1'

function croak() {
    echo ERROR: $* >&2
    exit 1
}

select dn in $(find . -type d -name 'DellFirmware*' -printf "%f\n" | sort -V); do 
    echo You selected $dn
    break
done
[[ -z $dn ]] && croak "Missing directory"
[[ -d $dn ]] || croak "'$dn' is not a directory"
echo OKAY $dn
