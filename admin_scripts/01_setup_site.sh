#!/bin/bash

# Populate the site table for a new xcat cluster

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


check_required_parameters() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _req_params=( MASTERIP DOMAIN )
    for v in "${_req_params[@]}"; do
        [[ -z "${!v}" ]] && croak "Missing required parameter: '$v'"
    done
}

get_pup_server() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _pupcmd=$(which puppet 2>/dev/null )
    local _pupserver=puppet
    [[ -n "$_pupcmd" ]] && {
        _pupserver=$( $_pupcmd config print server --section=agent )
    }
    echo $_pupserver
}


mk_stanza() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _forwarders=$( awk '/nameserver/ {
                          ns=ns "," $NF
                      }
                      END {
                        sub(/^,/,"",ns)
                        print ns
                      }' \
                 /etc/resolv.conf )
    local _puppetmaster=$( get_pup_server )
    cat <<ENDSTANZA
clustersite:
    objtype=site
    auditskipcmds=ALL
    domain=$DOMAIN
    fowarders=$_forwarders
    master=$MASTERIP
    nameservers=$_forwarders
    puppetmaster=$_puppetmaster
ENDSTANZA
}


usage() {
  cat <<ENDHERE

$PRG
    Populate the site table for a new xcat cluster.

Usage:
    $PRG [OPTIONS] --masterip <IPADDR> --domain <LOCAL.XCAT.DOMAIN>

PARAMETERS:
  --masterip   ip of xcat master node on the management network
               (where nodes will pxe boot)
  --domain     DNS domain name to be used on the management network

OPTIONS:
  -h    print help message and exit
  -n    dry-run, show what would be done, but don't make any changes

ENDHERE
}

DEBUG=$NO
DRYRUN=$NO
ENDWHILE=0
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
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

check_required_parameters

[[ $DEBUG -eq $YES ]] && set -x

# Populate site table
if [[ $DRYRUN -eq $YES ]] ; then
    mk_stanza
else
    mk_stanza | chdef -z
fi
#cmd='chdef -z'
#if [[ $DRYRUN -eq $YES ]] ; then
#    cmd='echo'
#fi
#mk_stanza | $cmd
##mk_stanza
