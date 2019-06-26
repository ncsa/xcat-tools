#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs
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


usage() {
  cat <<ENDHERE

$PRG
    Get hardware details for specific nodes.
Usage:
    $PRG [OPTIONS] {nodenames | noderange}
    where:
        nodenames must be a space separated list of valid nodenames
        or
        noderange must be a valid noderange expression understood by the 'nodels' command

OPTIONS:
  -h    print help message and exit
  -v    show what is happening

ENDHERE
}

ENDWHILE=0
VERBOSE=0
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -h) usage
        exit 0;;
    -v) VERBOSE=1;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

[[ $VERBOSE -eq 1 ]] && set -x

# Verify noderange
nodelist=( $( build_nodelist "$@" ) )

for n in "${nodelist[@]}" ; do
  # Get machine info
  rinv "$n" | grep -E 'Manufacturer ID|System Description|RDIMM|CPU .+ Product Version'

  # Get disk info
  xdsh "$n" 'lsblk -inbdo TYPE,SIZE,MODEL | sort -n -k2' 
done \
| xdshbak -c
