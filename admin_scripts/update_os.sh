#!/bin/bash

DEBUG=0

BASE=___INSTALL_DIR___
LIB=$BASE/libs
CLIENT_SCRIPTS=$BASE/client_scripts
TGT_DIR=/root/update_os
XCATBIN=/opt/xcat/bin
#TODO - make pause time adjustable via cmdline option
PAUSE=10

# Import libs
imports=( logging build_nodelist )
for f in "${imports[@]}"; do
    local _srcfn="${LIB}/${f}.sh"
    [[ -f "$_srcfn" ]] || {
        echo "Failed to find lib file '$_srcfn'"
        exit 1
    }
    source "$_srcfn"
done

sync_files_to_tgt() {
    local _tmpfn=$(mktemp)
    >>$_tmpfn cat <<ENDSYNCFILE
$LIB/* -> $TGT_DIR/libs
$CLIENT_SCRIPTS/gpfs_unmount.sh -> $TGT_DIR
$CLIENT_SCRIPTS/update_os.sh -> $TGT_DIR
ENDSYNCFILE
    $XCATBIN/xdcp "$tgtnode" -p -t 300 -F $_tmpfn
    rm $_tmpfn
}


pause() {
    [[ $DEBUG -eq 1 ]] && set +x #turn off debugging output for this function
    local _count=10
    [[ $1 -gt 0 ]] && _count=$1
    echo -n "Pause $_count "
    for x in $(seq $_count ); do
        sleep 1
        echo -n .
    done
    echo
    [[ $DEBUG -eq 1 ]] && set -x
}

[[ $DEBUG -eq 1 ]] && set -x

# Build nodelist from cmdline args
nodelist=( build_nodelist "$@" )

tmpdir=$( mktemp -d )
echo "OUTPUT LOGDIR: $tmpdir"
for node in "${nodelist[@]}"; do
    echo Start upgrade on $node
    logfn="$tmpdir/$node"
    (
    sync_files_to_tgt $node
    $XCATBIN/xdsh $node -t 900 "$TGT_DIR/update_os.sh"
    ) &>"$logfn" &
    pause $PAUSE
done
echo "OUTPUT LOGDIR: $tmpdir"
