YES=0
NO=1

croak() {
  echo "ERROR $*" >&2
  exit 99
}


warn() {
  echo "WARN $*" >&2
}


log() {
  [[ $VERBOSE -eq $YES ]] || return
  echo "INFO $*" >&2
}


debug() {
  [[ $DEBUG -eq $YES ]] || return
  echo "DEBUG (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


c_ok() {
    printf "\e[38;5;10mOK  \e[0m %s\n" "$1"
}


c_warn() {
    printf "\e[38;5;9mWARN\e[0m %s\n" "$1"
}
