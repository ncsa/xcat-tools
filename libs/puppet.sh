PUPPET=/opt/puppetlabs/bin/puppet


get_puppet_ensure_state() {
    [[ $DEBUG -eq $YES ]] && set -x
    $PUPPET resource service puppet \
    | awk '/ensure/ {gsub(/[^a-zA-Z]/,"",$NF);print $NF}'
}


get_puppet_enable_state() {
    [[ $DEBUG -eq $YES ]] && set -x
    $PUPPET resource service puppet \
    | awk '/enable/ {gsub(/[^a-zA-Z]/,"",$NF);print $NF}'
}


set_puppet_ensure_state() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _cur_state _tgt_state
    _tgt_state="$1"
    $PUPPET resource service puppet ensure="$_tgt_state"
    _cur_state=$( get_puppet_ensure_state )
    [[ "$_cur_state" == "$_tgt_state" ]]
}


set_puppet_enable_state() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _cur_state _tgt_state
    _tgt_state="$1"
    $PUPPET resource service puppet enable="$_tgt_state"
    _cur_state=$( get_puppet_enable_state )
    [[ "$_cur_state" == "$_tgt_state" ]]
}


puppet_agent_start() {
    [[ $DEBUG -eq $YES ]] && set -x
    set_puppet_ensure_state running
}


puppet_agent_stop() {
    [[ $DEBUG -eq $YES ]] && set -x
    set_puppet_ensure_state stopped
}


puppet_agent_enable() {
    [[ $DEBUG -eq $YES ]] && set -x
    set_puppet_enable_state true
}


puppet_agent_disable() {
    [[ $DEBUG -eq $YES ]] && set -x
    set_puppet_enable_state false
}
