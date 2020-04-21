get_bmc_ip() {
    # Get bmc ip addr for node
    # INPUT:
    #   1. Nodename
    # OUTPUT
    #   1. IP address of BMC interface
    local _bmcip
    local _node="$1"
    [[ -z "$_node" ]] && croak "get_bmc_ip: missing node name"
    # Try first to get bmc from nicips (new location)
    _bmc_ip=$( get_node_attr "$_node" nicips.bmc )
    [[ -z "$_bmc_ip" ]] && {
        # nicips.bmc not defined, so try legacy location
        _bmc_ip=$( get_node_attr "$_node" bmc )
    }
    echo "$_bmc_ip"
}


get_bmc_password() {
    # Get bmc password for node
    # INPUT:
    #   1. Nodename
    # OUTPUT
    #   1. Password for BMC interface
    local _bmc_pwd
    local _node="$1"
    [[ -z "$_node" ]] && croak "get_bmc_password: missing node name"
    _bmc_pwd=$( get_node_attr "$_node" bmcpassword )
    echo "$_bmc_pwd"
}


get_bmc_username() {
    # Get bmc user for node
    # INPUT:
    #   1. Nodename
    # OUTPUT
    #   1. user for BMC interface
    local _bmc_user
    local _node="$1"
    [[ -z "$_node" ]] && croak "get_bmc_username: missing node name"
    _bmc_user=$( get_node_attr "$_node" bmcusername )
    echo "$_bmc_user"
}


get_bmc_ip_user_pass() {
    # Convenience function to get bmc ip, username, password
    # INPUT:
    #   1. Nodename
    # OUTPUT
    #   1. Space-separated string with 3 values: ip, username, password
    local _ip _user _pass
    _ip=$( get_bmc_ip "$1" )
    _user=$( get_bmc_username "$1" )
    _pass=$( get_bmc_password "$1" )
    echo "$_ip" "$_user" "$_pass"
}
