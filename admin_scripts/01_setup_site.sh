#!/bin/bash

# Populate the site table for a new xcat cluster
# Set default netboot method
# Create useful, common xCAT groups

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )

# Import libs
imports=( logging )
for f in "${imports[@]}"; do
  _srcfn="${LIB}/${f}.sh"
  [[ -f "$_srcfn" ]] || {
    echo "Failed to find lib file '$_srcfn'"
    exit 1
  }
  source "$_srcfn"
done


assert_required_parameters_are_set() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _req_params=( MASTERIP DOMAIN )
  for v in "${_req_params[@]}"; do
    [[ -z "${!v}" ]] && croak "Missing required parameter: '$v'"
  done
}


assert_puppet_server_is_set() {
  [[ $DEBUG -eq $YES ]] && set -x
  if [[ -z "${PUPPETSERVER}" ]] ; then
    # no puppet server given on cmdline, try to get it from the local server
    local _pupcmd=$(which puppet 2>/dev/null )
    local _pupserver=''
    [[ -n "$_pupcmd" ]] && {
      _pupserver=$( $_pupcmd config print server --section=agent )
    }
    [[ -z "${_pupserver}" ]] \
    && croak "Cant determine puppet server. Run again with --puppetserver option.'"
    PUPPETSERVER="$_pupserver"
  fi
}


mk_stanza() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _forwarders=$( awk '
$0 ~ /nameserver/ && $0 !~ /127.0.0.1/ {
  ns=ns "," $2
}
END {
  sub(/^,/,"",ns)
  print ns
}' \
    /etc/resolv.conf )
  cat <<ENDSTANZA
clustersite:
  objtype=site
  auditskipcmds=ALL
  domain=$DOMAIN
  extntpservers=ntp.ncsa.illinois.edu,ntp.illinois.edu
  forwarders=$_forwarders
  master=$MASTERIP
  nameservers=$_forwarders
  puppetmaster=$PUPPETSERVER
  sshbetweennodes=NOGROUPS
  timezone="$TIMEZONE"
  xcatsslciphers="HIGH:!3DES"
  xcatsslversion=TLSv12
ENDSTANZA
}


set_default_netboot() {
	unset action
	[[ $DRYRUN -eq $YES ]] && action=echo
	$action chtab node=all noderes.netboot=xnba
}


assert_vmware_group() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _grname='vmware'
  local _cmds=( 'mkdef' '-z' )
  # do nothing if group is already defined
  lsdef -t group -o "$_grname" &>/dev/null && return $OK
  # do nothing if group is already defined
  lsdef -t group -o vmware &>/dev/null && return $OK
  # group is not defined, attempt to create it
	[[ $DRYRUN -eq $YES ]] && _cmds=( 'cat' )
  "${_cmds[@]}" <<ENDSTANZA
$_grname:
	objtype=group
	grouptype=static
	mgt=esx
	vmmanager=esx
ENDSTANZA
}


assert_physical_group() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _grname='physical'
  local _cmds=( 'mkdef' '-z' )
  # do nothing if group is already defined
  lsdef -t group -o "$_grname" &>/dev/null && return $OK
  # group is not defined, attempt to create it
	[[ $DRYRUN -eq $YES ]] && _cmds=( 'cat' )
  "${_cmds[@]}" <<ENDSTANZA
$_grname:
	objtype=group
	grouptype=static
	mgt=ipmi
	serialport=0
	serialspeed=115200
ENDSTANZA
}


assert_dell_group() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _grname='dell'
  local _action=''
  # do nothing if group is already defined
  lsdef -t group -o "$_grname" &>/dev/null && return $OK
  # group is not defined, attempt to create it
	[[ $DRYRUN -eq $YES ]] && _action='echo'
  $_action mkdef -t group dell
  $_action chtab node=dell ipmi.username=root ipmi.password=calvin
}


usage() {
  cat <<ENDHERE

$PRG
  Populate the site table for a new xcat cluster.

Usage:
  $PRG [OPTIONS] --masterip <IPADDR> --domain <LOCAL.XCAT.DOMAIN>

PARAMETERS:
  --domain    DNS domain name to be used on the management network
  --masterip  IP of xcat master node on the management network
              (where nodes will pxe boot)

OPTIONS:
  -h    print help message and exit
  -n    dry-run, show what would be done, but don't make any changes
  --puppetserver Hostname of the puppetserver to use for managed nodes.
                 (Defaults to the puppetserver used on by xcat.)
  --timezone  Defaults to "America/Chicago"

ENDHERE
}

DEBUG=$NO
DRYRUN=$NO
ENDWHILE=0
TIMEZONE="America/Chicago"
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -h)
        usage
        exit 0
        ;;
    -d)
        DEBUG=$YES
        ;;
    -n)
        DRYRUN=$YES
        ;;
    --domain)
        DOMAIN=$2;
        shift;;
    --masterip)
        MASTERIP=$2;
        shift;;
    --puppetserver)
        PUPPETSERVER=$2;
        shift;;
    --timezone)
        TIMEZONE=$2;
        shift;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

assert_required_parameters_are_set
assert_puppet_server_is_set

[[ $DEBUG -eq $YES ]] && set -x

# Populate site table
if [[ $DRYRUN -eq $YES ]] ; then
  mk_stanza
else
  mk_stanza | chdef -z
fi

# Set netboot type (XNBA, ...)
set_default_netboot

# Create useful, common xCAT groups
assert_vmware_group
assert_physical_group
assert_dell_group
