#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

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


get_imagename() {
  lsdef $1 | awk -F= '/provmethod/ {print $NF}'
}


usage() {
  cat <<ENDHERE

$PRG
    Get current provmethod for a node and re-assign it, 
    then set the node to PXE boot (netboot) once at next boot,
    then reboot the node, thus forcing a reinstall.
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
  -p S  Pause for S seconds between each node rebuild (default: 5)
ADVANCED OPTIONS:
  --osimage OSIMAGE  Set a custom osimage
  --shell            Boot to xCAT genesis shell
  --skip-osimage     Do NOT re-assign osimage, just set netboot and power cycle node

ENDHERE
}

ENDWHILE=0
VERBOSE=0
DRYRUN=0
PAUSE=5
SKIPOSIMAGE=0
SHELL=0
OSIMAGE=
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -h) usage
        exit 0;;
    -v) VERBOSE=1;;
    -n) DRYRUN=1;;
    -p) PAUSE=$2;
        shift;;
    --osimage) OSIMAGE=$2;
        shift;;
    --shell) SHELL=1; SKIPOSIMAGE=1;;
    --skip-osimage) SKIPOSIMAGE=1;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

[[ $VERBOSE -eq 1 ]] && set -x

# Build nodelist from cmdline args
nodelist=( $( build_nodelist "$@" ) )


# Do work for each node
action=
[[ $DRYRUN -ne 0 ]] && action="echo"
for n in "${nodelist[@]}" ; do
  nodeset_actions=()
  if [[ $SHELL -eq 1 ]] ; then
    nodeset_actions+=( shell )
  fi
  if [[ $SKIPOSIMAGE -lt 1 ]] ; then
    unset imagename
    if [[ -n "$OSIMAGE" ]] ; then
      imagename="$OSIMAGE"
    else
      imagename=$( get_imagename $n )
      [[ -z "$imagename" ]] && croak "Cant find imagename for node $n"
    fi
    nodeset_actions+=( "osimage=$imagename" )
  fi
  if [[ ${#nodeset_actions[*]} -gt 0 ]] ; then
    $action nodeset $n "${nodeset_actions[@]}" \
    || croak "nodeset returned nonzero ... check errors above for details"
  fi
  $action rsetboot $n net \
  || croak "rsetboot returned nonzero ... check errors above for details"
  $action rpower $n boot
  $action sleep $PAUSE >/dev/null
done
