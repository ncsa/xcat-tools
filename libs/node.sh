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


backup_node() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _node="$1"
    local _ts=${TS:-$(date +%s)}
    local _bkup_dir=/root/backups/xcat-nodes
    local _bkupfn="${_bkup_dir}/${_node}.${_ts}.bkup"
    mkdir -p "$_bkup_dir"
    lsdef "$_node" >"$_bkupfn"
    ls -l "$_bkupfn"
}


purge_node() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _node="$1"
    [[ $(nodels "$_node" | wc -l) -eq 1 ]] || return 0
    backup_node "$_node"
    nodepurge "$_node"
}
