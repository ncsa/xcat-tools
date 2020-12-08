#!/bin/bash

###
# Import libs
###
BASE=/root/xcat-tools
LIB=$BASE/libs
imports=( logging build_nodelist )
for f in "${imports[@]}"; do
  srcfn="${LIB}/${f}.sh"
  [[ -f "$srcfn" ]] || {
    echo "Failed to find lib file '$srcfn'"
    exit 1
  }
  source "$srcfn"
done


###
# GLOBAL VARIABLES
###

XCATBIN=/opt/xcat/bin
XDSH=$XCATBIN/xdsh
PRG=$(basename $0)
BKUP_BASE=/install/files/compute
NOW=$(date +%s)
REFRESH_DAYS=7

BACKUP_SOURCES=( \
  /etc/puppetlabs/puppet/ssl \
  /etc/puppetlabs/puppet/puppet.conf \
  /etc/krb5.keytab \
)


###
# FUNCTIONS
###

mk_tgz_name() {
  [[ $DEBUG -eq $YES ]] && set -x
  echo "$1" | tr -c 'a-zA-Z0-9.-' '_' | sed -e 's/^_//' -e 's/_$//'
}


is_stale() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _fn="$1"
  local _mtime=0
  [[ -e "$_fn" ]] && _mtime=$(date -r "$_fn" +%s)
  [[ $_mtime -le $MIN_BKUP_DATE ]]
}


bkup_node_data() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _node="$1"
  local _src="$2"
  local _tgt="$3"
  local _rv=0
  if client_has_path "$_node" "$_src" ; then
    log "Backup '$_src' -> '$_tgt'"
    ssh "$_node" "tar czP $_src" >"$_tgt"
    _rv=$?
  else
    log "Source '$_src' does not exist on node '$_node'. Skipping."
  fi
  return $_rv
}

client_has_path() {
  # Check if client has ssl certs to be backed up
  local node="$1"
  local path="$2"
  "$XDSH" "$node" -z "stat $path" &>/dev/null
}


usage() {
  cat <<ENDOFLINE

$PRG
  Backup puppet certs & config file on xcat master
  so they can be redeployed during node rebuild.
Usage:
  $PRG [-hfvd] [nodenames | noderange]
  where:
    nodenames must be a space separated list of valid nodenames
    or
    noderange must be a valid noderange expression understood by nodels
  If neither of nodenames or noderange are specified, $PRG will operate on all (known) nodes.

OPTIONS:
  -d         debug
  -f         forcefully pull client certs (default action will skip backups
             for nodes that have local files already.
  -h         print help message and exit
  -r         refresh rate, make a new backup every X days (default=7)
  -v         verbose

ENDOFLINE
}


###
#  MAIN CONTENTS
###

# CMDLINE OPTIONS
FORCE=$NO
VERBOSE=$NO
DEBUG=$NO
while getopts ":dfhr:v" opt; do
  case $opt in
  d)  DEBUG=$YES
    ;;
  f)  FORCE=$YES
    ;;
  h)  usage
    exit 0
    ;;
  r)  REFRESH_DAYS=$OPTARG
    ;;
  v)  VERBOSE=$YES
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
let "REFRESH_SECS = 86400 * $REFRESH_DAYS"
let "MIN_BKUP_DATE = $NOW - $REFRESH_SECS"
[[ $FORCE -eq $YES ]] && MIN_BKUP_DATE=$NOW

# ENABLE TRACING IF DEBUG REQUESTED
[[ $DEBUG -eq $YES ]] && set -x

if [[ $# -lt 1 ]] ; then
  nodelist=( $( build_nodelist all) )
else
  nodelist=( $( build_nodelist "$@" ) )
fi

BACKUP_TARGETS=()
for src in "${BACKUP_SOURCES[@]}"; do
    BACKUP_TARGETS+=( $(mk_tgz_name "$src" ) )
done

#for i in "${!BACKUP_SOURCES[@]}"; do
#  echo $i
#  echo "${BACKUP_SOURCES[$i]}"
#  echo "${BACKUP_TARGETS[$i]}"
#done
#exit 12

for n in "${nodelist[@]}" ; do
  log "Node: '$n'"
  node_bkup_dir="$BKUP_BASE/$n"
  mkdir -p "$node_bkup_dir"
  for i in "${!BACKUP_SOURCES[@]}"; do
    src="${BACKUP_SOURCES[$i]}"
    tgt_fn="${BACKUP_TARGETS[$i]}"
    bkup_tgt="$node_bkup_dir/${tgt_fn}.tgz"
    if is_stale "$bkup_tgt" ; then
      bkup_node_data "$n" "$src" "$bkup_tgt" \
      || warn "Failure detected during backup of '$src' from node '$n'"
    else
      log "OK '$src'"
      continue
    fi
  done
done
