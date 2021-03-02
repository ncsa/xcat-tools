#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )

# Import libs
imports=( logging build_nodelist node )
for f in "${imports[@]}"; do
  srcfn="${LIB}/${f}.sh"
  [[ -f "$srcfn" ]] || {
    echo "Failed to find lib file '$srcfn'"
    exit 1
  }
  source "$srcfn"
done


get_imagename() {
  get_node_attr "$1" provmethod
}


is_virtual() {
  local _rv=$NO
  get_node_attr "$1" mgt | grep -q 'esx\|kvm' && _rv=$YES
  get_node_attr "$1" groups | grep -q 'vmware' && _rv=$YES
  return $_rv
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

ENDWHILE=$NO
BOOT_TO_SHELL=$NO
DRYRUN=$NO
REBOOT_ALLOWED=$YES
OSIMAGE=
PAUSE=5
SKIPOSIMAGE=$NO
VERBOSE=$NO
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq $NO ]] ; do
  case $1 in
    -h) usage
        exit 0;;
    -v) VERBOSE=$YES;;
    -n) DRYRUN=$YES;;
    --noreboot)
        REBOOT_ALLOWED=$NO
        ;;
    --osimage)
        OSIMAGE=$2
        shift
        ;;
    -p) PAUSE=$2
        shift;;
    --shell)
        BOOT_TO_SHELL=$YES
        SKIPOSIMAGE=$YES
        ;;
    --skip-osimage)
        SKIPOSIMAGE=$YES
        ;;
    --) ENDWHILE=$YES;;
     *) ENDWHILE=$YES; break;;
  esac
  shift
done

[[ $VERBOSE -eq $YES ]] && set -x

# Build nodelist from cmdline args
nodelist=( $( build_nodelist "$@" ) )


# Do work for each node
action=
[[ $DRYRUN -eq $YES ]] && action="echo"
for n in "${nodelist[@]}" ; do
  nodeset_actions=()
  if [[ $BOOT_TO_SHELL -eq $YES ]] ; then
    nodeset_actions+=( shell )
  fi
  if [[ $SKIPOSIMAGE -eq $NO ]] ; then
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
  if is_virtual "$n" ; then
    [[ $REBOOT_ALLOWED -eq $YES ]] && $action xdsh "$n" reboot
  else
    $action rsetboot $n net \
    || croak "rsetboot returned nonzero ... check errors above for details"
    [[ $REBOOT_ALLOWED -eq $YES ]] && $action rpower $n boot
    $action sleep $PAUSE >/dev/null
  fi
done
