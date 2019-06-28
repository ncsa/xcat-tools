#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs
CMD=$0
PWD=$( dirname "$CMD" )

# Import libs
imports=( logging racadm )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done
DEBUG=$NO


setup() {
  FN_TMP=$( mktemp )
  FN_NICCONF=$( mktemp )
  all_tmp_files=( \
    $FN_TMP \
    $FN_NICCONF \
)
}


cleanup() {
  rm -rf "${all_tmp_files[@]}"
}


get_nicconfig() {
  fn=$FN_NICCONF
  nic_nums=( $( racadm $NODE get NIC.nicconfig | awk '/^NIC.nicconfig.[0-9] / { split($1, ary, /\./); print ary[3] }' ) )
  for n in "${nic_nums[@]}"; do
    # get FQDD (key) and boottype from nicconfig
    racadm $NODE get NIC.nicconfig.$n > $FN_TMP
    [[ $VERBOSE -eq $YES ]] && cat $FN_TMP
    nic_keys[$n]=$( awk -F= '/Key=NIC/ { split( $2, ary, /\#/ ); print ary[1] }' $FN_TMP )
    nic_boottypes[$n]=$( awk -F= '/BootProto/ { print $2 }' $FN_TMP )
    # get MAC and Link State from hwinventory
    racadm $NODE hwinventory ${nic_keys[$n]} > $FN_TMP
    mac_addrs[$n]=$( awk '/^Current MAC Address:/ { print $NF }' $FN_TMP )
    link_state[$n]=$( awk '
      /^Link Speed:/ { 
        lspeed = match( $3, /[0-9]/ )
        if ( lspeed > 0 ) { print "UP" }
        else { print "DOWN" }
      }' $FN_TMP )
    proto=${nic_boottypes[$n]}
    [[ -z "$proto" ]] && proto="undef"
    echo "$n ${nic_keys[$n]} ${link_state[$n]} ${mac_addrs[$n]} ${proto}" \
    | tee -a $fn
  done
}


pp_cmd() {
    # pass in arguments by reference
    # which means pass in the variable name (without the $ prefix)
    # for _cmdlist, pass the variable name as name[@]
    local _desc=${!1}
    local -a _cmdlist=("${!2}")
    printf "#\n# %s\n#\n" "$_desc"
    for _c in "${_cmdlist[@]}"; do
        printf "%s\n" "$_c"
    done
}


_mk_pxe_cmd() {
    local _enable="$1"
    local _action _value _parts _device _nic_id
    if [[ $_enable -eq $YES ]] ; then
        _search="UP"
        _action="enable"
        _value="PXE"
    else
        _search="PXE"
        _action="disable"
        _value="NONE"
    fi
    # get list of matching devices
    devlist=( $(awk "/$_search/ { print \$2 }" $FN_NICCONF ) )
    for _device in "${devlist[@]}"; do
        _nic_id=$( awk "/$_device/ { print \$1 }" $FN_NICCONF )
        local desc="Cmds to $_action PXE on $_device"
        local racadm="$PWD/racadm.sh"
        local cmds=( \
            "$racadm $NODE set nic.nicconfig.${_nic_id}.LegacyBootProto $_value" \
            "$racadm $NODE jobqueue create $_device" \
            "$racadm $NODE serveraction hardreset" \
            )
        pp_cmd desc cmds[@]
    done
}


mk_pxe_cmds() {
    _mk_pxe_cmd $YES
}


mk_un_pxe_cmds() {
    _mk_pxe_cmd $NO
}


check_pxe_status() {
    retval=0
    # ensure only one device set to pxeboot
    local _numpxedevs=$( grep PXE $FN_NICCONF | wc -l )
    if [[ $_numpxedevs -lt 1 ]] ; then
        c_warn "No PXE devices found"
        mk_pxe_cmds
        retval=1
    elif [[ $_numpxedevs -gt 1 ]] ; then
        c_warn "Multiple PXE devices found"
        mk_un_pxe_cmds
        retval=2
    fi
    return $retval
}


mk_xcat_cmd_setmac() {
    pxe_mac=$( awk '/PXE/ { print $4; exit }' $FN_NICCONF )
    local desc="Cmds to set MAC in xCAT"
    local cmds=( "chdef -t node $NODE mac=\"${pxe_mac}\"" )
    pp_cmd desc cmds[@]
}



print_usage() {
  cat <<ENDHERE
Usage: $CMD [options] nodename
Options:
  -v Verbose
  -h Help

Comments:
  Configure a nic: 
  1. racadm.sh <NODE> set nic.nicconfig.<NIC_ID>.LegacyBootProto <VAL>'
  2. racadm.sh <NODE> jobqueue create <DEVICe>
  3. racadm.sh <NODE> serveraction hardreset
       where:
         <NODE>   = nodename
         <NIC_ID> = integer id (from column one in normal output)
         <VAL>    = one of "PXE" or "NONE"
         <DEVICE> = device_name from column two in normal output
                    (ie: NIC.Integrated.1-3-1)
ENDHERE
}


VERBOSE=$NO
while getopts "hv <nodename>" val
do
  case $val in
    h) print_usage;;
    v) VERBOSE=$YES;;
    ?) print_usage;;
    :) print_usage;;
  esac
done
shift $((OPTIND-1))


[[ $# -eq 1 ]] || croak "missing host name"
NODE=$1

setup

### find pxe device
get_nicconfig
#cat $PWD/junk >$FN_NICCONF
#cat $FN_NICCONF

check_pxe_status && mk_xcat_cmd_setmac

cleanup
