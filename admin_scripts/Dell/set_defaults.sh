#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )

# Import libs
imports=( logging racadm node bmc questions )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


# iDRAC settings
declare -A _SETTINGS_RW

# List of FQDD keys to create jobqueues
# (used by functions in racadm)
declare -a FQDD_LIST

# an exit code
RETRY=2

#
# Local Functions
#


read_config() {
    [[ $DEBUG -eq $YES ]] && set -x
    # Load settings from config file
    local _conf_file="$1"
    [[ -z "$_conf_file" ]] && croak "read_config: missing conf_file"
    oldIFS="$IFS"; IFS='='
    while read -a parts; do
        _SETTINGS_RW["${parts[0]}"]="${parts[1]}"
    done
    IFS="$oldIFS"
}


enable_bios_bootmode() {
    [[ $DEBUG -eq $YES ]] && set -x
    # set bootmode to Bios
    _SETTINGS_RW['BIOS.BiosBootSettings.BootMode']='Bios'
    #_SETTINGS_RW['BIOS.BiosBootSettings.BootSeq']='HardDisk.List.1-1'
}


enable_uefi_bootmode() {
    [[ $DEBUG -eq $YES ]] && set -x
    # set bootmode to uefi
    _SETTINGS_RW['BIOS.BiosBootSettings.BootMode']='Uefi'
    _SETTINGS_RW['BIOS.NetworkSettings.PxeDev1EnDis']='Enabled'
    # Get PXE device
    log "Querying NICs for a PXE device ..."
    local _nicconfig=$( get_nicconfig )
    log "NIC config: '$_nicconfig'"
    local _pxe_fqdd=$( echo "$_nicconfig" | grep -F 'PXE' | head -1 | cut -d' ' -f2 )
    log "Got PXE device: '$_pxe_fqdd'"
    if [[ -z "$_pxe_fqdd" ]] ; then
        warn 'No PXE device found. Run get_netcfg.sh'
        return $ERR
    fi
    _SETTINGS_RW['BIOS.PxeDev1Settings.PxeDev1Interface']=$_pxe_fqdd
    _SETTINGS_RW['BIOS.PxeDev1Settings.PxeDev1Protocol']='IPv4'
}


set_settings() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _needs_reboot=$NO
    for key in "${!_SETTINGS_RW[@]}"; do
        cur_val=$( get_val "$key" )
        expected_val="${_SETTINGS_RW[$key]}"
        if ! match_ok "$cur_val" "$expected_val" ; then
            c_warn "$key=$cur_val"
            printf "\tAttempting to set $key=$expected_val\n"
            set_key_val "$key" "$expected_val"
            _needs_reboot=$YES
        fi
    done
    local _rc=$OK
    if [[ $_needs_reboot -eq $YES ]] ; then
        apply_settings
        _rc=$RETRY
    fi
    return $_rc
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
    Note that one of -b (bios) or -u (uefi) must be specified.

Usage:
    $PRG [OPTIONS] {-b|-u} {-c <CONFIG_FILE>} <NODE>

PARAMETERS:
    NODE   A node name, already configured with ipmi settings in xCAT

OPTIONS:
  --help,-h      print help message and exit
  --bios,-b      Choose BIOS boot mode type
  --config,-c    Config file to use for settings and values (Formatting: See NOTES)
  --clearall     Clear all pending changes and jobqueues
  --debug        Debug mode
  --dryrun,-n    Dry-run; Show existing values, but don't try to set anything
  --uefi,-u      Choose UEFI boot mode type
  --verbose,-v   Verbose mode
  --yes|-y       Answer yes to all prompts

NOTES:
* Config file format is KEY=value, one setting per line.
  (eg: BIOS.ProcSettings.LogicalProc=Enabled )

ENDHERE
}

CLEARALL=$NO
DEBUG=$NO
DRYRUN=$NO
ENDWHILE=0
FORCEYES=$NO
VERBOSE=$NO
ENABLE_UEFI_BOOT_MODE=$NO
ENABLE_BIOS_BOOT_MODE=$NO
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    --help|-h)
        usage
        exit 0
        ;;
    --bios|-b)
        ENABLE_BIOS_BOOT_MODE=$YES
        ;;
    --config|-c)
        CONFIG_FILE=$2
        shift
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
    --uefi|-u)
        ENABLE_UEFI_BOOT_MODE=$YES
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

[[ $ENABLE_UEFI_BOOT_MODE -eq $NO && $ENABLE_BIOS_BOOT_MODE -eq $NO ]] \
&& croak "Missing 'boot mode' type"

[[ $ENABLE_UEFI_BOOT_MODE -eq $YES && $ENABLE_BIOS_BOOT_MODE -eq $YES ]] \
&& croak "Choose exactly one 'boot mode' type"

[[ $# -lt 1 ]] && croak "Too few cmdline argurments.  Need 'nodename'"
NODE=$1
shift

[[ $DEBUG -eq $YES ]] && set -x

if [[ $CLEARALL -eq $YES ]] ; then
   clearall
   exit 0
fi

[[ $ENABLE_UEFI_BOOT_MODE -eq $YES ]] && enable_uefi_bootmode
[[ $ENABLE_BIOS_BOOT_MODE -eq $YES ]] && enable_bios_bootmode

if [[ $DRYRUN -eq $YES ]] ; then
    get_settings
    exit 0
fi

set_settings || set_settings 

get_settings
