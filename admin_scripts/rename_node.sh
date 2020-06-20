#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )
TS=$( date +%s )

# Import libs
imports=( logging node bmc questions )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done

DEBUG=$NO
#DEBUG=$YES


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

groups_chooser() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _done='>>DONE<<'
    local _abort='>>ABORT<<'
    local _all_groups=( $( lsdef -t group | cut -d' ' -f1 ) $_done $_abort )
    local _list=()
    local _groups_csv
    local _ok=$NO
    while [[ $_ok -eq $NO ]] ; do
        echo 'Choose groups. Press RETURN to see the list of options again.' 1>&2
        _list=()
        select new_group in "${_all_groups[@]}" ; do
            case $new_group in
                $_done)
                    break ;;
                $_abort|'')
                    _ok=$YES
                    croak 'Forced exit'
                    break;;
                *)
                    _list+=($new_group) ;;
            esac
        done
        _groups_csv=$( IFS=','; cat <<< "${_list[*]}" )
        echo "Group list: $_groups_csv" 1>&2
        ask_yes_no "Is this okay?" && _ok=$YES
    done
    echo "$_groups_csv"
}

get_groups() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _old_node=$1
    local _old_groups=$( get_node_attr $_old_node groups )
    local _custom='>>CUSTOM<<'
    local _abort='>>ABORT<<'
    echo 'Choose groups: ' 1>&2
    select grp in "$_old_groups" $_custom $_abort ; do
        case $grp in
            $_abort|'')
                croak 'Forced exit'
                break;;
            $_custom)
                echo "$(groups_chooser)"
                break;;
            "$_old_groups")
                echo "$_old_groups"
                break;;
        esac
    done
}

[[ $DEBUG -eq $YES ]] && set -x

if [[ $# -ne 2 ]] ; then
    croak 'Must specify OLD and NEW node names'
fi

old_node=$1
new_node=$2
shift 2


# GET INFO FROM OLD NODE
mgmt_ip=$( get_node_attr $old_node ip )
mgmt_mac=$( get_node_attr $old_node mac )
bmc_ip=$( get_bmc_ip $old_node )
groops=$( get_groups $old_node )
nicip_parts=( $( lsdef $old_node -i nicips | grep nicips ) )


# MAKE STANZA FILE FOR NEW NODE
bkup_dir=/root/backups/xcat-nodes
new_node_stanza_fn="/root/backups/xcat-nodes/${new_node}.${TS}.stanza"
mkdir -p $(dirname $new_node_stanza_fn)
echo "$new_node:" >$new_node_stanza_fn
<<ENDHERE cat >>$new_node_stanza_fn
    objtype=node
    arch=x86_64
    netboot=xnba
    nicnetworks.bmc=ipmi_net
    nictypes.bmc=bmc
    ip=$mgmt_ip
    mac=$mgmt_mac
    groups=$groops
ENDHERE
for nicip in "${nicip_parts[@]}" ; do
    echo "    $nicip" >>$new_node_stanza_fn
done


# PURGE NODES
if [[ $DEBUG -eq $NO ]] ; then
    echo 'About to purge nodes:'
    echo "    $old_node"
    echo "    $new_node"
    continue_or_exit || croak 'Forced Exit'
    purge_node $old_node
    purge_node $new_node
fi

# CREATE NEW NODE
actions=( mkdef -z )
[[ $DEBUG -eq $YES ]] && actions=( cat )
${actions[@]} <$new_node_stanza_fn
[[ $? -eq 0 ]] || exit 1

[[ $DEBUG -eq $NO ]] && lsdef $new_node


action=
[[ $DEBUG -eq $YES ]] && action=echo

set -x

$action makehosts $new_node
sleep 2
$action makedns $new_node
sleep 2
$action makedhcp -n
sleep 2
if [[ -n "$bmc_ip" ]] ; then
    $action makegocons $new_node
    sleep 2
    $action chdef $new_node bmc=${bmc_ip}
fi

#$action rinstall $new_node shell
