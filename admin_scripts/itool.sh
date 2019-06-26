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


assert_ipmitool() {
    # Ensure ipmitool is installed
    which ipmitool &>/dev/null || croak "'ipmitool' not found in path"
}


get_imagename() {
  lsdef $1 | awk -F= '/provmethod/ {print $NF}'
}


get_ipmi_credentials() {
    # eval defines variables: bmc, bmcusername, bmcpassword
    # as returned by the xCAT table "ipmi"
    eval $( lsdef -t node -o $1 -i bmc,bmcpassword,bmcusername | tail -n+2 )
    [[ -z "$bmc" ]] && croak "unknown ip for '$n'"
    [[ -z "$bmcpassword" ]] && croak "unknown ip for '$n'"
    [[ -z "$bmcusername" ]] && croak "unknown ip for '$n'"
}


usage() {
  cat <<ENDHERE

$PRG
    Run an ipmitool command on all nodes in nodelist.
Usage:
    $PRG [OPTIONS] {noderange} [ipmitool_cmdline_args]
    where:
        noderange must be a valid noderange expression understood by the 'nodels' command

OPTIONS:
  -d    enable debug mode
  -h    print help message and exit
  -v    enable verbose mode

ENDHERE
}

ENDWHILE=0
DEBUG=$NO
VERBOSE=$NO
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -d) DEBUG=$YES
        ;;
    -h) usage
        exit 0;;
    -v) VERBOSE=$YES
        ;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

[[ $VERBOSE -eq $YES ]] && set -x

# Build nodelist from cmdline args
nodelist=( $(build_nodelist "$1" ) )
shift

# Pass remaining cmdline args to ipmitool
declare -a ipmi_cmds=( "${@}" )
# Fail if no additional cmds given for ipmitool
[[ "${#ipmi_cmds[@]}" -lt 1 ]] && croak "Missing ipmi cmds"

assert_ipmitool

declare -a ipmi_opts=( '-I' lanplus \
                       '-e' '!'
                     )

# Do work for each node
for n in "${nodelist[@]}" ; do
    # defines variables: bmc, bmcusername, bmcpassword
    get_ipmi_credentials "$n"

    ipmitool "${ipmi_opts[@]}" \
        -H "${bmc}" \
        -U "${bmcusername}" \
        -P "${bmcpassword}" \
        "${ipmi_cmds[@]}"
done
