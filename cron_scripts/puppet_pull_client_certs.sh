#!/bin/bash

###
# GLOBAL VARIABLES
###

BASE=___INSTALL_DIR___
LIB=$BASE/libs
XCATBIN=/opt/xcat/bin
XDSH=$XCATBIN/xdsh
XDCP=$XCATBIN/xdcp
NODELS=$XCATBIN/nodels
SSLDIR=/etc/puppetlabs/puppet/ssl
BKUP_SSLDIR=/install/files/compute/var/lib/puppet/ssl
PRG=$(basename $0)
tmpdir=$(mktemp -d )


# Import libs
imports=( logging )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


###
# FUNCTIONS
###

client_has_certs() {
    # Check if client has ssl certs to be backed up
    node=$1
    xdsh $node -z "ls $SSLDIR/certs"
}

get_client_certs() {
  # copy ssl dir (recursively) from NODE
  [[ $DEBUG -eq 1 ]] && set -x
  node=$1
  client_has_certs $node || return 1
  $XDCP $node -P -R $SSLDIR $tmpdir
  hostdir=${tmpdir}/ssl._$n
  mv "$hostdir" "$BKUP_SSLDIR/$node"
}


do_bkup_certs_exist() {
  [[ $DEBUG -eq 1 ]] && set -x
  node=$1
  [[ -d "$BKUP_SSLDIR/$node/certs" ]]
}


usage() {
  cat <<ENDOFLINE

$PRG
    Backup puppet client certs on xcat master so they can be redeployed during node rebuild.
Usage:
    $PRG [-pDhfvd] [nodenames | noderange]
    where:
        nodenames must be a space separated list of valid nodenames
        or
        noderange must be a valid noderange expression understood by nodels
    If neither of nodenames or noderange are specified, $PRG will operate on all (known) nodes.

OPTIONS:
  -h         print help message and exit
  -f         forcefully pull client certs (default action will skip nodes that have been backed up before)
  -v         verbose
  -d         debug

ENDOFLINE
}


###
#  MAIN CONTENTS
###

# CMDLINE OPTIONS
FORCE=0
VERBOSE=0
DEBUG=0
while getopts ":hfvd" opt; do
    case $opt in
    h)  usage
        exit 0
        ;;
    f)  FORCE=1
        ;;
    v)  VERBOSE=1
        ;;
    d)  DEBUG=1
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
  esac
done
shift $((OPTIND-1))

# ENABLE TRACING IF DEBUG REQUESTED
[[ $DEBUG -eq 1 ]] && set -x

[[ -d $BKUP_SSLDIR ]] || mkdir -p $BKUP_SSLDIR

if [[ $# -lt 1 ]] ; then
  nodelist=( $( $NODELS all) )
elif [[ $# -eq 1 ]] ; then
  nodelist=( $( $NODELS $1 ) )
else
  nodelist=( $( for a in $*; do $NODELS $a; done ) )
fi

for n in "${nodelist[@]}" ; do
  log "Node: '$n'"
  if [[ $FORCE -ne 1 ]] ; then
    do_bkup_certs_exist $n && {
      log "OK" 
      continue
    }
  fi
  log "NEW"
  get_client_certs $n || {
    warn "Failed to get client certs from node '$n'"
    continue
  }
done

rm -rf $tmpdir


### DIR STRUCTURE AFTER xdcp
#/tmp/tmp.D6jnyJyy07
#└── ssl._cg-cmp08
#    ├── certificate_requests
#    │   └── cg-cmp08.ncsa.illinois.edu.pem
#    ├── certs
#    │   ├── ca.pem
#    │   └── cg-cmp08.ncsa.illinois.edu.pem
#    ├── crl.pem
#    ├── private
#    ├── private_keys
#    │   └── cg-cmp08.ncsa.illinois.edu.pem
#    └── public_keys
#        └── cg-cmp08.ncsa.illinois.edu.pem

