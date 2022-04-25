#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )
TS=$( date +%s )

# Import libs
imports=( logging node )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


print_template() {
  cat <<ENDHERE
# xcat node name
NODE=ctlr2

# If node is VMware, skip these
#BMC_IP=192.168.180.20
# Name of the ipmi network in the xCAT "network" table
#BMC_NETNAME=srvc
# bmc user/pass can be picked up from an xCAT group
#BMC_USER=
#BMC_PASS=

MGMT_IP=10.142.180.20
MGMT_MAC=00:8C:FA:FB:F0:5A
# mgmt_type can be picked up from an xCAT group
#MGMT_TYPE=ipmi

# Set this only if node will have a public ip and if xcat will set it up
# *NOTE* public interface in VMware is ens224
#PUBLIC_IP=141.142.180.20
#PUBLIC_INTF=ens224

# comma separated list of xcat groups
# if node is VMware, remember to add it to the vmware group
# remember to add <INTF>_protected or <INTF>_public, such as: ens224_public
# VMware example: GROOPS=ens224_protected,vmware,all
GROOPS=undefined,all
ENDHERE
}

print_usage() {
  cat <<ENDHERE
$PRG - Create or recreate a node definition to xCAT.

Usage: $PRG [options] NODEFILE

Options:
  -d|--debug)    Enable debug mode; lots of messages and run in dry-run mode
  -h|--help)     Print this help message and exit
  -t|--template) Print a sample NODEFILE template
  --no-hosts)    Do not run makehosts
  --no-dns)      Do not run makedns
  --no-dhcp)     Do not run makedhcp
ENDHERE
}

# Read cmdline options and parameters
DEBUG=$NO
ENDWHILE=$NO
RUN_MAKEDNS=$YES
RUN_MAKEDHCP=$YES
RUN_MAKEHOSTS=$YES
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq $NO ]] ; do
  case $1 in
    -d|--debug)     DEBUG=$YES;;
    -h|--help)      print_usage; exit 0;;
    -t|--template)  print_template; exit 0;;
    --no-dns)       RUN_MAKEDNS=$NO;;
    --no-dhcp)      RUN_MAKEDHCP=$NO;;
    --no-hosts)     RUN_MAKEHOSTS=$NO;;
    --)             ENDWHILE=$YES;;
    -*)             echo "Invalid option '$1'"; exit 1;;
     *)             ENDWHILE=$YES; break;;
  esac
  shift
done
echo "DEBUG=$DEBUG"

# Check for NODEFILE
[[ $# -eq 1 ]] || croak "Missing NODEFILE. Try --help option for more details."
NODEFILE="$1"
[[ -r "$NODEFILE" ]] || croak "NODEFILE '$NODEFILE' not found or not readable"
. "$NODEFILE"

set -x

# Check for gocons
MKGOCONS=$(which makegocons 2>/dev/null) \
|| MKGOCONS=$(which makeconservercf ) \
|| croak "Failed to find makegocons or makeconservercf"

action=purge_node
[[ $DEBUG -eq $YES ]] && action=echo
nodels $NODE &>/dev/null && {
    $action $NODE || exit 1
}

actions=( mkdef -z )
[[ $DEBUG -eq $YES ]] && actions=( cat )
${actions[@]} <<ENDHERE
$NODE:
    objtype=node
    arch=x86_64
    netboot=xnba
    groups=$GROOPS
    ip=$MGMT_IP
    mac=$MGMT_MAC
    ${MGMT_TYPE:+mgt=$MGMT_TYPE}
    ${BMC_IP:+nicips.bmc=$BMC_IP}
    ${BMC_IP:+nictypes.bmc=bmc}
    ${BMC_IP:+nicnetworks.bmc=$BMC_NETNAME}
    ${BMC_PASS:+bmcpassword=$BMC_PASS}
    ${BMC_USER:+bmcusername=$BMC_USER}
    ${PUBLIC_IP:+nicips.$PUBLIC_INTF=$PUBLIC_IP}
ENDHERE

[[ $? -eq 0 ]] || exit 1

action=
[[ $DEBUG -eq $YES ]] && action=echo

# Extra bmc info for legacy xcat tools
[[ -n $BMC_IP ]] && $action chdef $NODE bmc=${BMC_IP}
sleep 1

if [[ $RUN_MAKEHOSTS -eq $YES ]] ; then
  $action makehosts $NODE
  sleep 1
fi

if [[ $RUN_MAKEDNS -eq $YES ]] ; then
  $action makedns $NODE
  sleep 1
fi

if [[ $RUN_MAKEDHCP -eq $YES ]] ; then
  $action makedhcp $NODE
  sleep 1
fi

[[ -n $BMC_IP ]] && $action $MKGOCONS $NODE

