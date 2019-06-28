#!/bin/bash

trap "exit 1" TERM

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )

# All settings that should be set
declare -A _SETTINGS_RW=( ['BIOS.ProcSettings.LogicalProc']='Disabled' \
                          ['BIOS.SysProfileSettings.SysProfile']='PerfOptimized' \
                          ['BIOS.BiosBootSettings.BootMode']='Bios' \
                          ['BIOS.BiosBootSettings.BootSeq']='HardDisk.List.1-1' \
)

# Import libs
imports=( logging racadm questions )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done

# List of FQDD keys to create jobqueues
declare -a FQDD_LIST


#
# Local Functions
#


set_settings() {
    [[ $DEBUG -eq $YES ]] && set -x
    # skip if dry-run was requested
    [[ $DRYRUN -eq $YES ]] && return 0
    for key in "${!_SETTINGS_RW[@]}"; do
        cur_val=$( get_val "$key" )
        expected_val="${_SETTINGS_RW[$key]}"
        if ! match_ok "$cur_val" "$expected_val" ; then
            c_warn "$key=$cur_val"
            printf "\tAttempting to set $key=$expected_val\n"
            set_key_val "$key" "$expected_val"
        fi
    done
    apply_settings
}


get_settings() {
    [[ $DEBUG -eq $YES ]] && set -x
    for key in "${!_SETTINGS_RW[@]}"; do
        val=$( get_val "$key" )
        expected_val="${_SETTINGS_RW[$key]}"
        if match_ok "$val" "$expected_val" ; then
            c_ok "$key=$val"
        else
            c_warn "$key=$val [Expected '$expected_val']"
        fi
    done
}


clearall() {
    [[ $DEBUG -eq $YES ]] && set -x
    # attempt to set a jobqueue, the key doesn't matter since
    # it will be immediately deleted
    racadm $NODE jobqueue create BIOS.Setup.1-1
    racadm $NODE jobqueue delete --all
}


usage() {
  cat <<ENDHERE

$PRG
    Configure iDRAC settings with useful default values.

Usage:
    $PRG [OPTIONS] <NODE>

PARAMETERS:
    NODE   A node name, already configured with ipmi settings in xCAT

OPTIONS:
  --help,-h      print help message and exit
  --clearall     Clear all pending changes and jobqueues
  --debug        Debug mode
  --dryrun,-n    Dry-run; Show existing values, but don't try to set anything
  --yes|-y       Answer yes to all prompts

ENDHERE
}

CLEARALL=$NO
DEBUG=$NO
DRYRUN=$NO
ENDWHILE=0
FORCEYES=$NO
VERBOSE=$NO
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    --help|-h)
        usage
        exit 0
        ;;
    --clearall)
        CLEARALL=$YES
        ;;
    --debug|-d)
        DEBUG=$YES
        ;;
    --dryrun|-n)
        DRYRUN=$YES
        ;;
    --verbose|-v)
        VERBOSE=$YES
        ;;
    --yes|-y)
        FORCEYES=$YES
        ;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

[[ $# -lt 1 ]] && croak "Too few cmdline argurments.  Need 'nodename'"
NODE=$1
shift

[[ $DEBUG -eq $YES ]] && set -x

if [[ $CLEARALL -eq $YES ]] ; then
   clearall
   exit 0
fi

set_settings

get_settings
