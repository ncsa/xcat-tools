#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs
CMD=$0

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
  FN_BIOSBOOTSEQ=$( mktemp )
  FN_IPMILAN=$( mktemp )
  FN_LOGICALPROC=$( mktemp )
  all_tmp_files=( \
    $FN_TMP \
    $FN_NICCONF \
    $FN_BIOSBOOTSEQ \
    $FN_IPMILAN \
    $FN_LOGICALPROC \
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


get_biosbootseq() {
  fn=$FN_BIOSBOOTSEQ
  racadm $NODE get BIOS.BiosBootSettings.BootSeq > $fn
  [[ $VERBOSE -eq $YES ]] && cat $fn
}


get_ipmilan() {
  fn=$FN_IPMILAN
  racadm $NODE get iDRAC.IPMILan.Enable > $fn
  [[ $VERBOSE -eq $YES ]] && cat $fn
  awk -F= 'BEGIN { retval=2 }
/^Enable=/ && $2 == "Enabled" { retval=0; exit }
/^Enable=/ && $2 == "Disabled" { retval=1; exit }
END { exit retval }
' $FN_IPMILAN
  rc=$?
  if [[ $rc -eq 1 ]] ; then
    warn 'IPMI Lan not enabled'
  elif [[ $rc -gt 1 ]] ; then
    croak 'IPMI Lan setting not found or unknown value'
  fi
  return $rc
}


get_logicalproc() {
  fn=$FN_LOGICALPROC
  racadm $NODE get BIOS.ProcSettings.LogicalProc > $fn
  [[ $VERBOSE -eq $YES ]] && cat $fn
  awk -F= 'BEGIN { retval=2 }
/^LogicalProc=/ && $2 == "Enabled" { retval=1; exit }
/^LogicalProc=/ && $2 == "Disabled" { retval=0; exit }
END { exit retval }
' $fn
  rc=$?
  if [[ $rc -eq 1 ]] ; then
    warn 'LogicalProc enabled'
  elif [[ $rc -gt 1 ]] ; then
    croak 'Logical Proc setting not found or unknown value'
  fi
  return $rc
}

print_usage() {
  cat <<ENDHERE
Usage: $CMD [options] nodename
Options:
  -v Verbose
  -h Help
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

# ensure only one device set to pxeboot
numpxedevs=$( grep PXE $FN_NICCONF | wc -l )
#[[ $numpxedevs -lt 1 ]] && warn "No PXE devices found"
#[[ $numpxedevs -gt 1 ]] && warn "Multiple PXE devices found"
#pxe_key=$( awk '/PXE/ { print $2; exit }' $FN_NICCONF )
#echo "PXE DEVICE: $pxe_key"
#
#pxe_mac=$( get_mac $pxe_key )
#echo "PXE MAC ADDRESS: $pxe_mac"
echo
echo "Set mac in xcat using: 'nodech $NODE mac.mac=\"<MAC_ADDR>\"'"
echo

get_biosbootseq

get_ipmilan

get_logicalproc

cleanup
