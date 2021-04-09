#!/bin/bash 

# --- Make no changes here. Go down to MAIN ---

### GLOBAL SETTINGS
YES=0
NO=1
OK=0
ERR=1


### FUNCTIONS

croak() {
  printf "\e[40;31mERROR\e[0m  %s\n" "$1" >&2
  kill -s TERM ${XCAT_TOOLS_TOP_PID:-$BASHPID}
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
  local msg="Continue, Skip, or Exit?"
  [[ -n "$1" ]] && msg="$1"
  echo "$msg" 1>&2
  select answer in "Continue" "Skip" "Exit"; do
    case $answer in
      Continue) return 0;;
      Skip ) return 1;;
      Exit ) croak "User Exit";;
    esac
  done
}


usage() {
  cat <<ENDHERE
Environment Variables to set (and sample formats)
  #export XCAT_CLUSTER_PASSWD="apassword"
  #export XCAT_MN_DHCP_INTF="ens192"
  #export XCAT_MN_DOMAIN="internal.ncsa.edu"
  #export XCAT_MN_DYN_RANGE="141.142.199.240-141.142.199.245"
  #export XCAT_MN_IP="172.28.18.18"
  
ENDHERE
}


check_envs() {
  log "About to do: ${FUNCNAME[0]}"
  [[ "$DEBUG" == "$YES" ]] && set -x
  for _var in \
    XCAT_CLUSTER_PASSWD \
    XCAT_MN_DHCP_INTF \
    XCAT_MN_DOMAIN \
    XCAT_MN_DYN_RANGE \
    XCAT_MN_IP \
    ; do
    if [[ -z "${!_var}" ]] ; then
      warn "Environment variable not set '$_var'"
      usage
      croak "Missing environment variable '$_var'"
    fi
    log $(env | grep "$_var")
  done
  set +x
}


install_xcat() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  yum -y install git yum-utils
  curl -o /root/go-xcat \
    https://raw.githubusercontent.com/xcat2/xcat-core/master/xCAT-server/share/xcat/tools/go-xcat
  chmod +x /root/go-xcat
  /root/go-xcat -y install
  source /etc/profile.d/xcat.sh
  # UPDATE
  /root/go-xcat -y update
  set +x
}


install_tools() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  yum -y install python3
  export QS_GIT_REPO=https://github.com/ncsa/xcat-tools
  curl https://raw.githubusercontent.com/andylytical/quickstart/master/quickstart.sh | bash
}


configure_site() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  # SITE
  /root/xcat-tools/admin_scripts/01_setup_site.sh --masterip "$XCAT_MN_IP" --domain "$XCAT_MN_DOMAIN"
  # CHECK
  lsdef -t site -i domain,forwarders,master,nameservers,auditskipcmds,puppetmaster
  # DEFAULT CLUSTER PASSWD
  chtab key=system passwd.username=root passwd.password="$XCAT_CLUSTER_PASSWD"
}


configure_networks() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  # NETWORKS
  local _xcat_net_names=( $( lsdef -t network | awk '{print $1}' ) )
  echo "Which network is the mgmt (pxeboot) net?"
  select response in "${_xcat_net_names[@]}" "Skip" "Exit"; do
    case $response in
      Skip )
        log "skipped network setup"
        break
        ;;
      Exit )
        croak "User Exit"
        ;;
      * )
        chdef -t network -o "$response" -n mgmt_net
        break
        ;;
    esac
  done
  # continue only if mgmt_net is defined
  if lsdef -t network -o mgmt_net &>/dev/null ; then
    # Add a 'dynamicrange' to the mgmt network
    chdef -t network mgmt_net dynamicrange="$XCAT_MN_DYN_RANGE"
    lsdef -t network -l
    # DNS
    chdef -t site externaldns=1
    makedns -n
    # DHCP
    chdef -t site dhcpinterfaces="$XCAT_MN_DHCP_INTF"
    makedhcp -n
    systemctl restart named
  fi
}


configure_groups() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  # XNBA
  chtab node=all noderes.netboot=xnba

  # GROUPS
  mkdef -z <<ENDHERE
vmware:
    objtype=group
    grouptype=static
    mgt=esx
    vmmanager=esx
ENDHERE

  mkdef -z <<ENDHERE
physical:
    objtype=group
    grouptype=static
    mgt=ipmi
    serialport=0
    serialspeed=115200
ENDHERE
}


check_setup() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  xcatprobe xcatmn -i "$XCAT_MN_DHCP_INTF"
}


###
#   MAIN
###

#DEBUG=$YES

check_envs

install_xcat

install_tools

configure_site

configure_networks

configure_groups

check_setup
