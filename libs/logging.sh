croak() {
  echo "ERROR $*" >&2
  exit 99
}


warn() {
  echo "WARN $*" >&2
}


log() {
  [[ $VERBOSE -ne 1 ]] && return
  echo "INFO $*" >&2
}


debug() {
  [[ $DEBUG -ne 1 ]] && return
  echo "DEBUG (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}
