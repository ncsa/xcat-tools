#!/bin/bash


###
# GLOBAL VARIABLES
###

BASE=___INSTALL_DIR___
LIB=$BASE/libs
XCATBIN=/opt/xcat/bin
XDCP=$XCATBIN/xdcp
NODELS=$XCATBIN/nodels
KEYTABDIR=/etc
BKUP_KEYTABDIR=/install/files/compute/var/lib/kerberos/keytab
PRG=$(basename $0)


# Import libs
imports=( logging )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


###
# FUNCTIONS
###


does_kerberos_keytab_exist() {
  [[ $DEBUG -eq 1 ]] && set -x
  node=$1
  [[ -f "$BKUP_KEYTABDIR/${node}.krb5.keytab" ]]
}


get_kerberos_keytab() {
  [[ $DEBUG -eq 1 ]] && set -x
  node=$1
  $XDCP $node -P "$KEYTABDIR/krb5.keytab" "$BKUP_KEYTABDIR"
}


usage() {
  cat <<ENDOFLINE

$PRG
    Backup kerberos keytab files on xcat master so they can be redeployed during node rebuild.
Usage:
    $PRG [-pDhfvd] [nodenames | noderange]
    where:
        nodenames must be a space separated list of valid nodenames
        or
        noderange must be a valid noderange expression understood by nodels
    If neither of nodenames or noderange are specified, $PRG will operate on all (known) nodes.

OPTIONS:
  -h         print help message and exit
  -f         force overwrite existing local keytab backup files
             (default action will skip nodes that have been backed up before)
  -v         verbose
  -d         debug

ENDOFLINE
}


###
#  MAIN CONTENTS
###

# CMDLINE OPTIONS
FORCE=0
VERBOSE=0
DEBUG=0
while getopts ":hfvd" opt; do
    case $opt in
    h)  usage
        exit 0
        ;;
    f)  FORCE=1
        ;;
    v)  VERBOSE=1
        ;;
    d)  DEBUG=1
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
  esac
done
shift $((OPTIND-1))

# ENABLE TRACING IF DEBUG REQUESTED
[[ $DEBUG -eq 1 ]] && set -x

# Create bkup dir
[[ -d $BKUP_KEYTABDIR ]] || mkdir -p $BKUP_KEYTABDIR

# Process nodelist
if [[ $# -lt 1 ]] ; then
  nodelist=( $( $NODELS all) )
elif [[ $# -eq 1 ]] ; then
  nodelist=( $( $NODELS $1 ) )
else
  nodelist=( $( for a in $*; do $NODELS $a; done ) )
fi

# Loop through all nodes one at a time
for n in "${nodelist[@]}" ; do
  log "Node: '$n'"
  if [[ $FORCE -ne 1 ]] ; then
    # skip node if local file already exists
    does_kerberos_keytab_exist "$n" && {
      log "OK" 
      continue
    }
  fi
  log "NEW"
  get_kerberos_keytab "$n" || {
    warn "Failed to get client keytab from node '$n'"
    continue
  }
  # Post process local (bkup) file
  src="${BKUP_KEYTABDIR}/krb5.keytab._$n"
  tgt="$BKUP_KEYTABDIR/${n}.krb5.keytab"
  mv "$src" "$tgt"
  chmod 440 "$tgt"
  log $(ls -l "$tgt")

done
