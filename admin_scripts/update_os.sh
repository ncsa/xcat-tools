#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
CLIENT_SCRIPTS=$BASE/client_scripts
LIB=$BASE/libs
TGT_DIR=/root/update_os
XCATBIN=/opt/xcat/bin
PRG="$0"

# Import libs
imports=( logging build_nodelist )
for f in "${imports[@]}"; do
    _srcfn="${LIB}/${f}.sh"
    [[ -f "$_srcfn" ]] || {
        echo "Failed to find lib file '$_srcfn'"
        exit 1
    }
    source "$_srcfn"
done

sync_files_to_tgt() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _tgtnode="$1"
    local _tmpfn=$(mktemp)
    $XCATBIN/xdsh "$_tgtnode" "rm -rf $TGT_DIR"
    >>$_tmpfn cat <<ENDSYNCFILE
$LIB/* -> $TGT_DIR/libs
$CLIENT_SCRIPTS/gpfs_unmount.sh -> $TGT_DIR
$CLIENT_SCRIPTS/update_os.sh -> $TGT_DIR
ENDSYNCFILE
    $XCATBIN/xdcp "$_tgtnode" -p -t 300 -F $_tmpfn
    rm $_tmpfn
}


pause() {
    [[ $DEBUG -eq $YES ]] && set +x #turn off debugging output for this function
    local _count=10
    [[ $1 -gt 0 ]] && _count=$1
    echo -n "Pause $_count "
    for x in $(seq $_count ); do
        sleep 1
        echo -n .
    done
    echo
    [[ $DEBUG -eq $YES ]] && set -x
}

usage() {
    cat <<ENDHERE

$PRG
    Copy os-upgrade scripts to the client node and (optionally) run them.

USAGE:
    $PRG [OPTIONS]

OPTIONS:
    -h --help
        print help message and exit
    -d --debug
        Enable debug output
    -n --norun
        Copy scripts to remote node but don't run anything
        (Default = copy scripts and run them)
        (Note: also sets pause to 0, can re-enable by explicitly setting --pause)
    -p --pause
        Pause X seconds between nodes (Default = $PAUSE)
        (Helpful to stagger yum updates for large numbers of nodes
        if nodes all pull yum updates from the same internal server)
    -q --quiet
        Disable all verbose and debug output
        (Default = enable verbose output)

ENDHERE
}

# Customizable parameters
DEBUG=$NO
PAUSE=10
STARTUPDATES=$YES
VERBOSE=$YES

# Process cmdline options
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--debug)
            DEBUG=$YES
            ;;
        -n|--norun)
            STARTUPDATES=$NO
            PAUSE=0
            ;;
        -p|--pause)
            shift
            PAUSE=$1
            ;;
        -q|--quiet)
            VERBOSE=$NO
            ;;
        --)
            ENDWHILE=1
            ;;
        *)
            ENDWHILE=1
            break
            ;;
    esac
    shift
done

[[ $DEBUG -eq $YES ]] && set -x

# Build nodelist from cmdline args
nodelist=( $( build_nodelist "$@" ) )

if [[ $STARTUPDATES -eq $YES ]] ; then
    tmpdir=$( mktemp -d )
    log "OUTPUT LOGDIR: $tmpdir"
fi

for node in "${nodelist[@]}"; do
    log "Copy client scripts to $node"
    sync_files_to_tgt $node
    if [[ $STARTUPDATES -eq $YES ]] ; then
        log "Starting update on $node"
        logfn="$tmpdir/$node"
        (
            $XCATBIN/xdsh $node -t 900 "$TGT_DIR/update_os.sh"
        ) &>"$logfn" &
    fi
    [[ $PAUSE -gt 0 ]] && pause $PAUSE
done
[[ $STARTUPDATES -eq $YES ]] && log "OUTPUT LOGDIR: $tmpdir"
