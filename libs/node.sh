get_node_attr() {
    # Get the content of ATTR for a given NODE
    # INPUT:
    #   1. Nodename
    #   2. Attribute
    # OUTPUT
    #   1. Content of Attribute (emptystring if Attribute is undefined)
    local _node="$1"
    local _attrname="$2"
    local _attrval
    [[ -z "$_node" ]] && croak "get_node_attr: missing node name"
    [[ -z "$_attrname" ]] && croak "get_node_attr: missing attribute name"
    _attrval=$( lsdef -t node -o "$_node" -i "$_attrname" \
                | grep "$_attrname" \
                | cut -d= -f2 )
    echo "$_attrval"
}
