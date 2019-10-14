#!/bin/bash

###
# GLOBAL VARIABLES
###

BASE=___INSTALL_DIR___
LIB=$BASE/libs
XCATBIN=/opt/xcat/bin
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

get_client_certs() {
  [[ $DEBUG -eq 1 ]] && set -x
  node=$1
  $XDCP $node -P -R $SSLDIR $tmpdir
}


do_client_certs_exist() {
  [[ $DEBUG -eq 1 ]] && set -x
  node=$1
  retval=1
  count=$(find $BKUP_SSLDIR -name "*${node}.*.pem"  | wc -l)
  [[ $count -gt 0 ]] && retval=0
  return $retval
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

[[ -d $BKUP_SSLDIR ]] || mkdir -p $BKUP_SSLDIR/{certs,private_keys,public_keys}

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
    do_client_certs_exist $n && {
      log "OK" 
      continue
    }
  fi
  log "NEW"
  get_client_certs $n || {
    warn "Failed to get client certs from node '$n'"
    continue
  }

  hostdir=${tmpdir}/ssl._$n
  for subdir in certs private_keys public_keys; do
    srcdir=${hostdir}/$subdir
    fn=$( find $srcdir -name "*${n}.*.pem" -printf '%f' )
    if [[ -z "$fn" ]] ; then
      warn "No pem file found in '$srcdir'"
      continue
    fi
    src=$srcdir/$fn
    tgt=$BKUP_SSLDIR/$subdir/$fn
    mv $src $tgt
    chmod 644 $tgt
  done
  log $( find $BKUP_SSLDIR -name $fn -exec ls -l {} \; )
done

# If ca.pem is not found, copy the one from this node
# (this will work only if ca.pem from localhost is the same as remote host)
# (but better than nothing, since without ca.pem, nothing will work)
[[ -f $BKUP_SSLDIR/certs/ca.pem ]] || \
cp $SSLDIR/certs/ca.pem $BKUP_SSLDIR/certs/ca.pem

rm -rf $tmpdir

#root@cg-adm01:~/admin-scripts# find /install/files/compute/var/lib/puppet/ssl -name '*cmp09*'
#/install/files/compute/var/lib/puppet/ssl/private_keys/cg-cmp09.ncsa.illinois.edu.pem
#/install/files/compute/var/lib/puppet/ssl/certs/cg-cmp09.ncsa.illinois.edu.pem
#/install/files/compute/var/lib/puppet/ssl/public_keys/cg-cmp09.ncsa.illinois.edu.pem

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

