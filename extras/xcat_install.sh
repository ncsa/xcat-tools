#!/bin/bash

#DEBUG=1

### GLOBAL SETTINGS
YES=0
NO=1
OK=0
ERR=1


### FUNCTIONS

croak() {
  printf "\e[40;31mERROR\e[0m  %s\n" "$1" >&2
  kill 0
  exit 99
}


debug() {
  [[ $DEBUG -eq $YES ]] || return
  echo "DEBUG (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


log() {
  printf "\e[40;32mINFO\e[0m  %s\n" "$1"
}


warn() {
  printf "\e[40;33mWARN\e[0m  %s\n" "$1"
}

ask_continue() {
  local _rv=$NO
  local _msg="Continue, Skip, or Exit?"
  [[ -n "$1" ]] && _msg="$1"
  echo "$_msg" 1>&2
  select answer in "Continue" "Skip" "Exit"; do
    case $answer in
      Continue) _rv=$YES;;
      Skip ) _rv=$NO;;
      Exit ) croak "User Exit";;
    esac
    break
  done
  return $_rv
}


install_xcat() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  # epel
  yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  # dependencies
  yum -y install git yum-utils
  # xcat
  curl -o /root/go-xcat \
    https://raw.githubusercontent.com/xcat2/xcat-core/master/xCAT-server/share/xcat/tools/go-xcat
  chmod +x /root/go-xcat
  /root/go-xcat -y install
  # source /etc/profile.d/xcat.sh
  # UPDATE
  # /root/go-xcat -y update
  set +x
}


### MAIN

install_xcat
