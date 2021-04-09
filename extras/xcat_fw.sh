#!/bin/sh

DEBUG=1
XCAT_MGMT_NETS=( 141.142.192.0/21 )
#XCAT_IPMI_NETS=( 172.31.68.0/22 192.168.21.0/24 )
#DATA_NETWORKS=( 172.31.64.0/22 )
SSH_ALLOWED_SOURCES=( 141.142.148.24/32 141.142.148.5/32 141.142.236.22/32 141.142.236.23/32 )


remove_firewalld() {
  # https://linuxize.com/post/how-to-stop-and-disable-firewalld-on-centos-7/
  # https://access.redhat.com/solutions/3897641
  [[ $DEBUG -eq 1 ]] && set -x
  systemctl stop nftables firewalld
  systemctl disable nftables firewalld
  systemctl mask --now nftables firewalld
}


ensure_iptables() {
  # https://linuxize.com/post/how-to-install-iptables-on-centos-7/
  [[ $DEBUG -eq 1 ]] && set -x
  yum install iptables-services
  systemctl start iptables
  systemctl start ip6tables
  systemctl enable iptables
  systemctl enable iptables
}


iptables_xcat_mgmt() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}"; do
    iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 53,67,68,69,80,123,514,782,873,2049,3001,3002,4011 \
    -j ACCEPT

    iptables -A INPUT \
    -s "${src}" \
    -p udp \
    -m multiport --dports 53,69,80,123,514,873,2049,3001,3002 \
    -j ACCEPT
  done
}

iptables_xcat_ipmi() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_IPMI_NETS[@]}"; do
    iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 25 \
    -j ACCEPT

    iptables -A INPUT \
    -s "${src}" \
    -p udp \
    -m multiport --dports 53,69,80,123,514,873,2049,3001,3002 \
    -j ACCEPT
  done
}


iptables_squid() {
  [[ $DEBUG -eq 1 ]] && set -x
  for src in "${XCAT_MGMT_NETS[@]}" "${DATA_NETWORKS[@]}"; do
    iptables -A INPUT \
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
    iptables -A INPUT \
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
    iptables -A INPUT \
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
    iptables -A INPUT \
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
    iptables -A INPUT \
    -s "${src}" \
    -p tcp \
    -m multiport --dports 22 \
    -j ACCEPT
  done
}


iptables_clear() {
  for cmd in iptables ip6tables; do
    for table in 'nat' 'filter'; do
      "$cmd" -t "$table" -Z
      "$cmd" -t "$table" -F
      "$cmd" -t "$table" -X
    done
  done
}


iptables_defaults() {
  for cmd in iptables ip6tables; do
    for chain in INPUT FORWARD; do
      "$cmd" -P "$chain" DROP
    done
  done
}


iptables_begin() {
  [[ $DEBUG -eq 1 ]] && set -x
  iptables -A INPUT -i lo -j ACCEPT
  ip6tables -A INPUT -i lo -j ACCEPT

  iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

  iptables -A INPUT -p icmp -j ACCEPT
  # An exception to duplication is the ICMP rule below where ipv6-icmp is needed to correctly handle ICMP in IPv6
  ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
}


iptables_end() {
  [[ $DEBUG -eq 1 ]] && set -x
  iptables -A INPUT -j DROP
  ip6tables -A INPUT -j DROP
}


bkup_existing_iptables() {
  [[ $DEBUG -eq 1 ]] && set -x
  iptables-save >iptables.bkup.$(date +%s)
}


configure_iptables() {
  iptables_clear
  iptables_defaults
  iptables_begin
  iptables_ssh
  iptables_xcat_mgmt
  iptables_xcat_ipmi
  # iptables_squid
  # iptables_puppet
  # iptables_chrony
  # iptables_rsyslog
  iptables_end
}


[[ $DEBUG -eq 1 ]] && set -x

remove_firewalld

ensure_iptables

bkup_existing_iptables

configure_iptables
