#!/bin/bash

DEBUG=0


function die() {
  echo "ERROR: $*"
  exit 99
}

function pause() {
    [[ $DEBUG -eq 1 ]] && set +x #turn off debugging output for this function
    count=2
    [[ $1 -gt 0 ]] && count=$1
    echo -n "Pause $count "
    for x in $(seq $count ); do
        sleep 1
        echo -n .
    done
    echo
    [[ $DEBUG -eq 1 ]] && set -x
}


[[ $DEBUG -eq 1 ]] && set -x

### Build NODERANGE from cmdline args
if [[ $# -lt 1 ]] ; then
    die "Must specify nodename"
elif [[ $# -eq 1 ]] ; then
  NODERANGE=( $( nodels $1 ) )
else
  NODERANGE=( $( for a in $*; do nodels $a; done ) )
fi

tmpdir=./$(date +%Y%m%dT%H%M%S)
mkdir $tmpdir || die "Failed to make tempdir '$tmpdir'"
for node in "${NODERANGE[@]}"; do
    logfn="$tmpdir/$node"
    set -x
    /opt/xcat/bin/pasu $node show all &>"$logfn"
    set +x
done
