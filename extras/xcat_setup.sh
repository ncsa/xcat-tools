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


ask_yes_no() {
  local _rv=$NO
  local _msg="Is this ok?"
  [[ -n "$1" ]] && _msg="$1"
  echo "$_msg" 1>&2
  select yn in "Yes" "No"; do
    case $yn in
      Yes) _rv=$YES;;
      No ) _rv=$NO;;
    esac
    break
  done
  return $_rv
}


ask_additional_networks() {
  local _rv=$NO
  echo "Configure additional networks?" 1>&2
  select answer in "Yes" "No" "Help" "Quit"; do
    case $answer in
      Yes)
        _rv=$YES
        break
        ;;
      No )
        _rv=$NO
        break
        ;;
      Quit )
        croak "User Exit"
        break
        ;;
      Help ) cat 1>&2 <<ENDHERE
      ============================
      Help for Additional Networks
      ----------------------------
      [Yes]  -> if you already have a stanza file (you will be asked for the path later)
      [No]   -> if network configuration is done
      [Quit] -> exit this script to go make a stanza file
      [Help] -> this help message
      If additional networks are needed, choose [Quit], then ...
      for each additional network to be configured,
      make a copy of /root/xcat-tools/extras/xcat_network_stanza_template,
      edit the copied file(s) to update the network configuration details,
      restart this setup script and
      skip the previous steps until this configure_network step
      ============================

ENDHERE
      ;;
    esac
  done
  return $_rv
}



ask_user() {
  [[ -z "$1" ]] && croak "missing prompt in call to ask_user"
  local _msg="$1"
  printf "\e[40;33mINPUT REQUIRED\e[0m  %s\n" "$_msg" 1>&2
  echo "( Ctl-d or Enter to quit )" 1>&2
  read || croak "User Exit Requested"
  [[ ${#REPLY} -lt 1 ]] && croak "Nothing read. Exiting"
  echo "$REPLY"
}


ask_network_stanza_file() {
  local _user_fn _realpath
  while /bin/true ; do
    _user_fn=$( ask_user "Enter the path to the network stanza file" )
    _realpath=$( realpath -e "$_user_fn" )
    if [[ -f "$_realpath" ]] ; then
      break
    else
      warn "File not found '$_realpath'"
    fi
  done
  echo "$_realpath"
}


get_cluster_passwd() {
  [[ "$XCAT_SETUP_CLUSTER_PASSWD" ]] && return
  XCAT_SETUP_CLUSTER_PASSWD=$( ask_user "xCAT cluster passwd" )
}


get_domain() {
  [[ "$XCAT_SETUP_DOMAIN" ]] && return
  XCAT_SETUP_DOMAIN=$( ask_user "xCAT cluster domain" )
}


get_mn_ip() {
  [[ "$XCAT_SETUP_MN_IP" ]] && return
  local _ip_addrs=$( ip -4 -o a s \
    | awk '$2 !~ /lo/ {split($4, parts, "/"); print parts[1];}' )
  if [[ "${#_ip_addrs[*]}" -lt 1 ]] ; then
    croak "No usable nics found"
  elif [[ "${#_ip_addrs[*]}" -eq 1 ]] ; then
    XCAT_SETUP_MN_IP="$_ip_addrs"
  else
    echo "Select the IP addr for the pxeboot network" 1>&2
    select addr in "${_ip_addrs[@]}"; do
      if [[ -n "$addr" ]] ; then
        XCAT_SETUP_MN_IP="$addr"
      else
        croak "Empty selection for XCAT_SETUP_MN_IP"
      fi
    done
  fi
}


check_xcat() {
  [[ -d /opt/xcat ]] || croak "xCAT not installed"
}


check_envs() {
  log "About to do: ${FUNCNAME[0]}"
  local _rv=$OK
  [[ "$DEBUG" == "$YES" ]] && set -x
  get_cluster_passwd
  get_domain
  get_mn_ip
  for _var in \
    XCAT_SETUP_CLUSTER_PASSWD \
    XCAT_SETUP_DOMAIN \
    XCAT_SETUP_MN_IP \
    ; do
    if [[ -z "${!_var}" ]] ; then
      warn "Environment variable not set '$_var'"
      _rv=$ERR
    else
      log "$_var = ${!_var}"
    fi
  done
  set +x
  return $_rv
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
  /root/xcat-tools/admin_scripts/01_setup_site.sh --masterip "$XCAT_SETUP_MN_IP" --domain "$XCAT_SETUP_DOMAIN"
  makentp -V
  # CHECK
  lsdef -t site -i domain,forwarders,master,nameservers,auditskipcmds,puppetmaster
  # DEFAULT CLUSTER PASSWD
  chtab key=system passwd.username=root passwd.password="$XCAT_SETUP_CLUSTER_PASSWD"
}


get_dhcp_nic_names() {
  [[ "$DEBUG" == "$YES" ]] && set -x
  lsdef -t network -z \
  | awk -F= '$1~/mgtifname/ {print $2}' \
  | sort -u
}


configure_networks() {
  log "About to do: ${FUNCNAME[0]}"
  ask_continue || return 1
  [[ "$DEBUG" == "$YES" ]] && set -x
  # NETWORKS
  local _pxeboot_xcat_name _pxeboot_net_name _dyn_range _net_stanza_fn
  local _new_nets=$NO
  local _xcat_net_names=( $( lsdef -t network | awk '{print $1}' ) )
  lsdef -t network -i net,mask,gateway
  echo "Which network is the mgmt (pxeboot) net?"
  select response in "${_xcat_net_names[@]}" "Skip" "Exit"; do
    case $response in
      Skip )
        log "skipped network setup"
        return 1
        ;;
      Exit )
        croak "User Exit"
        ;;
      * )
        _pxeboot_xcat_name="$response"
        break
        ;;
    esac
  done
  _pxeboot_net_name="$_pxeboot_xcat_name"
  if ask_yes_no "Rename network?" ; then
    _pxeboot_net_name=$( ask_user "New network name?" )
    chdef -t network -o "$_pxeboot_xcat_name" -n "$_pxeboot_net_name"
  fi
  # Add a 'dynamicrange' to the mgmt network
  if ask_yes_no "Add a dynamic dhcp range to $_pxeboot_net_name ?" ; then
    _dyn_range=$( ask_user "Dynamic dhcp range (format: a.b.c.d-w.x.y.z)" )
    chdef -t network -o "$_pxeboot_net_name" dynamicrange="$_dyn_range"
  fi
  # Add dhcp server
  chdef -t network -o "$_pxeboot_net_name" dhcpserver="$XCAT_SETUP_MN_IP"
  # Additional Networks
  while ask_additional_networks ; do
    _net_stanza_fn=$( ask_network_stanza_file )
    chdef -z <"$_net_stanza_fn"
    _new_nets=$YES
  done
  # DHCP interfaces
  for _intf in $( get_dhcp_nic_names ); do
    chdef -t site --plus dhcpinterfaces="$_intf"
  done
  makedhcp -n
  systemctl restart named
  # Make new net discovery files in /tftpboot/xcat/xnba/nets/*
  [[ $_new_nets -eq $YES ]] && mknb x86_64
}


configure_dns() {
  if ask_yes_no "Use external DNS?" ; then
    chdef -t site externaldns=1
  fi
  makedns -n
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
  network_intfs=( $( get_dhcp_nic_names | grep -vF remote ) )
  for _intf in "${network_intfs[@]}"; do
    echo
    log "XCAT MN SETUP CHECK FOR INTERFACE '$_intf'"
    xcatprobe xcatmn -i "$_intf"
  done
}


###
#   MAIN
###

#DEBUG=$YES

check_xcat

check_envs || croak "Missing essential data. Fix warnings above and restart."

#install_tools

configure_site

configure_networks

configure_dns

configure_groups

check_setup
