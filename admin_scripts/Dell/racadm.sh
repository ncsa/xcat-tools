#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
LIB=$BASE/libs

# Import libs
imports=( logging racadm node bmc questions )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done
VERBOSE=$NO
DEBUG=$NO


[[ $# -lt 2 ]] && croak "Too few cmdline argurments.  Need 'hostname' and 'racadm cmd'"
node=$1
shift
racadm $node $*
