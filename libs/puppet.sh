PUPPET=/opt/puppetlabs/bin/puppet


get_puppet_ensure_state() {
    $PUPPET resource service puppet \
    | awk '/ensure/ {gsub(/[^a-zA-Z]/,"",$NF);print $NF}'
}


get_puppet_enable_state() {
    $PUPPET resource service puppet \
    | awk '/enable/ {gsub(/[^a-zA-Z]/,"",$NF);print $NF}'
}


set_puppet_ensure_state() {
    local _cur_state _tgt_state
    _tgtstate="$1"
    $PUPPET resource service puppet ensure="$tgt_state"
    _cur_state=$( get_puppet_ensure_state )
    [[ "$_cur_state" == "$tgt_state" ]]
}


set_puppet_enable_state() {
    local _cur_state _tgt_state
    _tgtstate="$1"
    $PUPPET resource service puppet enable="$tgt_state"
    _cur_state=$( get_puppet_enable_state )
    [[ "$_cur_state" == "$tgt_state" ]]
}


puppet_agent_start() {
    set_puppet_ensure_state running
}


puppet_agent_stop() {
    set_puppet_ensure_state stopped
}


puppet_agent_enable() {
    set_puppet_enable_state true
}


puppet_agent_disable() {
    set_puppet_enable_state false
}
