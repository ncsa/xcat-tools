#!/bin/bash

#
# SETTINGS
#
YES=0
NO=1
DEBUG=$YES
DEBUG=$NO
NICTYPE=ethernet

#
# FUNCTIONS
#
get_net_obj() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _netname="$1"
  local _objname="$2"
  echo $( lsdef -t network -o "${_netname}" -i "${_objname}" | tail -1 | cut -d'=' -f2 )
}


#
# DO WORK
#
cmds=( 'chdef' '-z' )
if [[ $DEBUG -eq $YES ]] ; then
  set -x
  cmds=( 'cat' )
fi

# interfaces that xcat knows about
ifnames=( $( lsdef -t network -l | grep mgtifname | grep -v '!remote' | cut -d '=' -f2 ) )

# networks defined to xcat
netnames=( $( lsdef -t network | cut -d' ' -f1 ) )
 
# Create a route and group for each INTERFACE + NETWORK combination
for intf_name in "${ifnames[@]}"; do
  comment="${intf_name}_interface"
  for net_name in "${netnames[@]}"; do
    gw=$( get_net_obj "$net_name" gateway )
    net=$( get_net_obj "$net_name" net )
    mask=$( get_net_obj "$net_name" mask )
    route_name="${intf_name}_${net_name}"
    group_name="$route_name"
    # Define route
    "${cmds[@]}" <<ENDROUTE
$route_name:
    objtype=route
    net=$net
    mask=$mask
    gateway=$gw
    ifname=$intf_name
    usercomment="$comment"
ENDROUTE
    # Define nodegroup
    "${cmds[@]}" <<ENDGROUP
$group_name:
    objtype=group
    nictypes.${intf_name}=${NICTYPE}
    nicnetworks.${intf_name}=${net_name}
    routenames=$route_name
ENDGROUP
 
    done
done
