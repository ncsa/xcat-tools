#!/bin/sh

# for DRYRUN, uncomment below
action=echo; DEBUG=1

DEBUG=1
TS="$(date +%s)"
XCAT_MGMT_NETS=(
  141.142.192.0/21 \
  172.28.18.0/24 \
  172.28.20.0/23 \
)
#XCAT_IPMI_NETS=( 172.31.68.0/22 192.168.21.0/24 )
#DATA_NETWORKS=( 172.31.64.0/22 )
SSH_ALLOWED_SOURCES=(
  141.142.148.24/32 \
  141.142.148.5/32 \
  141.142.236.22/32 \
  141.142.236.23/32 \
)


remove_firewalld() {
  # https://linuxize.com/post/how-to-stop-and-disable-firewalld-on-centos-7/
  # https://access.redhat.com/solutions/3897641
  [[ $DEBUG -eq 1 ]] && set -x
  for svc in nftables firewalld ; do
    $action systemctl disable --now "$svc"
    $action systemctl mask "$svc"
  done
}


ensure_iptables() {
  # https://linuxize.com/post/how-to-install-iptables-on-centos-7/
  [[ $DEBUG -eq 1 ]] && set -x
  $action yum install iptables-services ebtables ipset-service
  for svc in iptables ip6tables ebtables ipset ; do
    $action systemctl enable --now "$svc"
  done
}


reset() {
  for cmd in iptables ip6tables; do
    $action $cmd -F #flush rules
    $action $cmd -X #delete chains
    $action $cmd -Z #flush counters
  done
}


iptables_xcat_mgmt() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}"; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 53,67,68,69,80,123,514,782,873,2049,3001,3002,4011 \
    -j ACCEPT

    $action iptables -A INPUT \
    -s "${src}" \
    -p udp \
    -m multiport --dports 53,69,80,123,514,873,2049,3001,3002 \
    -j ACCEPT
  done
}

iptables_xcat_ipmi() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_IPMI_NETS[@]}"; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 25 \
    -j ACCEPT

    $action iptables -A INPUT \
    -s "${src}" \
    -p udp \
    -m multiport --dports 53,69,80,123,514,873,2049,3001,3002 \
    -j ACCEPT
  done
}


iptables_squid() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}" "${DATA_NETWORKS[@]}"; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 3128 \
    -m comment --comment "squid-proxy" \
    -j ACCEPT
  done
}


iptables_puppet() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}"; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 8140 \
    -m comment --comment "Puppet" \
    -j ACCEPT
  done
}


iptables_rsyslog() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}" ; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p udp \
    -m multiport --dports 20515 \
    -m comment --comment "rsyslog?" \
    -j ACCEPT
  done
}


iptables_chrony() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}"; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p udp \
    -m multiport --dports 123 \
    -m comment --comment "chrony" \
    -j ACCEPT
  done
}


iptables_ssh() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${SSH_ALLOWED_SOURCES[@]}"; do
    $action iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 22 \
    -j ACCEPT
  done
}


iptables_clear() {
  for cmd in iptables ip6tables; do
    for table in 'nat' 'filter'; do
      $action "$cmd" -t "$table" -Z
      $action "$cmd" -t "$table" -F
      $action "$cmd" -t "$table" -X
    done
  done
}


iptables_defaults() {
  for cmd in iptables ip6tables; do
    for chain in INPUT FORWARD; do
      $action "$cmd" -P "$chain" DROP
    done
  done
}


iptables_begin() {
  [[ $DEBUG -eq 1 ]] && set -x
  $action iptables -A INPUT -i lo -j ACCEPT
  $action ip6tables -A INPUT -i lo -j ACCEPT

  $action iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  $action ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

  # ICMP from NCSA
  $action iptables -A INPUT -s 141.142.0.0/16 -p icmp -j ACCEPT
  # Ping from anywhere
  $action iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
  # IPv6 ICMP from anywhere
  $action ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
}


iptables_end() {
  [[ $DEBUG -eq 1 ]] && set -x
  for net in "141.142.0.0/16" ; do
    for table in INPUT FORWARD ; do
      $action iptables -A "$table" -s "$net" -m comment --comment "Reject from NCSA" -j REJECT
    done
  done
  $action ip6tables -A INPUT -s 2620:0:0c80::/48 -m comment --comment "Reject from NCSA" -j REJECT
}


bkup_existing_iptables() {
  [[ $DEBUG -eq 1 ]] && set -x
  $action mkdir -p /root/bkup
  $action iptables-save -f /root/bkup/${TS}.iptables
  $action ip6tables-save -f /root/bkup/${TS}.ip6tables
}


configure_iptables() {
  iptables_clear
  iptables_begin
  iptables_ssh
  iptables_xcat_mgmt
  iptables_xcat_ipmi
  # iptables_squid
  # iptables_puppet
  # iptables_chrony
  # iptables_rsyslog
  iptables_end
  iptables_defaults
}


save_iptables() {
  # https://access.redhat.com/solutions/60562
  $action iptables-save -f /etc/sysconfig/iptables
  $action ip6tables-save -f /etc/sysconfig/ip6tables
}


[[ $DEBUG -eq 1 ]] && set -x

remove_firewalld

ensure_iptables

bkup_existing_iptables

reset

configure_iptables

save_iptables
