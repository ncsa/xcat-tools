#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs
REMOTESSLDIR=/etc/puppetlabs/puppet/ssl
LOCALSSLDIR=/install/files/compute/var/lib/puppet/ssl
PRG=$( basename $0 )

# Import libs
imports=( logging build_nodelist )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


delete_remote_certs() {
  [[ $VERBOSE -eq 1 ]] && set -x
  action='-delete'
  [[ $DRYRUN -eq 1 ]] && action='-print'
  nodename=$1
  xdsh $nodename find $REMOTESSLDIR -type f -name '*.pem' $action
}


delete_local_certs() {
  [[ $VERBOSE -eq 1 ]] && set -x
  action='-delete'
  [[ $DRYRUN -eq 1 ]] && action='-print'
  nodename=$1
  find $LOCALSSLDIR -type f -name "*$nodename*.pem" $action
}


usage() {
  cat <<ENDHERE

$PRG
    Clean puppet certs on client and cert backups on xcat master.
Usage:
    $PRG [OPTIONS] {nodenames | noderange}
    where:
        nodenames must be a space separated list of valid nodenames
        or
        noderange must be a valid noderange expression understood by the 'nodels' command

OPTIONS:
  -h    print help message and exit
  -v    show what is happening
  -n    show existing files/data, don't actually remove anything

ENDHERE
}

ENDWHILE=0
VERBOSE=0
DRYRUN=0
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -h) usage
        exit 0;;
    -v) VERBOSE=1;;
    -n) DRYRUN=1;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done


# Build nodelist from cmdline args
nodelist=( $( build_nodelist "$@" ) )


### Do work for each node
for n in "${nodelist[@]}" ; do
  delete_remote_certs $n
  delete_local_certs $n
done
