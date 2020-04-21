racadm() {
    # run a racadm command on a node
    # INPUT:
    #   1. Nodename
    # OUTPUT:
    #   1. output from the racadm tool
    [[ $DEBUG -eq $YES ]] && set -x
    local _ip _usr _pwd
    local _node="$1"; shift
    [[ -z "$_node" ]] && croak "racadm: missing nodename"
    _ip=$( get_bmc_ip "$_node" )
    [[ -z "$_ip" ]] && croak "unknown ip for '$_node'"
    _usr=$( get_bmc_username "$_node" )
    [[ -z "$_usr" ]] && croak "unknown username for '$_node'"
    _pwd=$( get_bmc_password "$_node" )
    [[ -z "$_ip" ]] && croak "unknown password for '$_node'"
    SSHPASS="$_pwd" sshpass -e ssh -l $_usr $_ip -- racadm "$*" \
    | grep -v 'efault \(user\|password\)'
    unset SSHPASS
}


extract_fqdd() {
    # INPUT should be pipe'd to this command
    # Output from running a racadm set command is a key called fqdd
    # needed for creating a jobqueue action that will apply the setting
    # Format is [Key=BIOS.Setup.1-1#ProcSettings]
    awk -F= '/^\[Key=/ { split( $2, ary, /\#/ ); print ary[1] }'
}


ra_out_is_success() {
    # Output from a racadm command is successful
    local retval=1
    local ra_out="$1"
    local ok_codes=( RAC1017 \
                     RAC1024 \
                     "power operation initiated successfully" 
                   )
    for code in "${ok_codes[@]}"; do
        if [[ "$ra_out" =~ "$code" ]] ; then
            retval=0
        fi
    done
    return $retval
}


ra_out_has_error() {
    # Check string for error conditions
    echo "$1" | grep -q -i 'ERROR'
}


check_racadm_output() {
    # INPUT rac_response - output from racadm cmd
    # INPUT msg - msg to print on failure
    local rac_response="$1"
    local msg="$2"
    if ra_out_has_error "$rac_response" ; then
        echo "$rac_response"
        croak "Caught error at: $msg"
    elif ra_out_is_success "$rac_response" ; then
        : #pass
    else
        echo "$rac_response"
        croak "Unknown response from racadm at: $msg"
    fi
}


_wait_for_iDRAC_jobqueues(){
    [[ $DEBUG -eq $YES ]] && set -x
    printf 'Waiting up to 5 mins for iDRAC jobqueues to complete.'
    for i in $(seq 6); do 
        sleep 10
        printf '.'
    done
    for i in $(seq 20); do 
        num_incomplete_jobs=$( racadm "$NODE" jobqueue view \
                               | grep -F 'Percent Complete' \
                               | grep -v -F 'Percent Complete=[100]' \
                               | wc -l )
        [[ $num_incomplete_jobs -lt 1 ]] && break
        sleep 10
        printf '.'
    done
    echo
}


apply_settings() {
    [[ $DEBUG -eq $YES ]] && set -x
    if [[ $FORCEYES -eq $NO ]] ; then
        continue_or_exit "About to apply changes. 
If you choose to exit, you should first run again with --clearall to clear partial and pending changes.
Continue?"
    fi
    printf '%s\n' "${FQDD_LIST[@]}" \
    | sort -u \
    | head -1 \
    | while read; do
        cmdparts=("$NODE" jobqueue create "$REPLY" '-r' pwrcycle)
        log "racadm ${cmdparts[@]}"
        output=$( racadm "${cmdparts[@]}" )
        check_racadm_output "$output" "attempt to '${cmdparts[*]}'"
    done
#    output=$( racadm $NODE serveraction hardreset )
#    check_racadm_output "$output" "attempt to serveraction hardreset"
    _wait_for_iDRAC_jobqueues
}


set_key_val() {
    [[ $DEBUG -eq $YES ]] && set -x
    local key="$1"
    local val="$2"
    local retval=2
    local output fqdd
    output=$( racadm $NODE set "$key" "$val" )
    # Check for error
    if ra_out_has_error "$output" ; then
        echo "$output"
        c_warn "attempting to set '$key' '$val' resulted in an error"
        return 1
    fi
    # extract key
    fqdd=$( extract_fqdd <<< "$output" )
    FQDD_LIST+=( "$fqdd" )
    log "Adding "$fqdd" to jobqueue list"
}


get_val() {
    [[ $DEBUG -eq $YES ]] && set -x
    key="$1"
    racadm $NODE get "$key" \
    | tail -n 1 \
    | awk -F= '{match($0,/=(.*)$/,ary);print ary[1]}'
}


match_ok() {
    raw_val="$1"
    expected_val="$2"
    echo "$raw_val" | grep -iq "^${expected_val}"
}


get_nicconfig() {
    local _tmpf=$(mktemp)
    nic_nums=( $( racadm $NODE get NIC.nicconfig | awk '/^NIC.nicconfig.[0-9] / { split($1, ary, /\./); print ary[3] }' ) )
    for n in "${nic_nums[@]}"; do
        # get FQDD (key) and boottype from nicconfig
        racadm $NODE get NIC.nicconfig.$n > $_tmpf
        [[ $DEBUG -eq $YES ]] && cat $_tmpf >&2
        nic_keys[$n]=$( awk -F= '/Key=NIC/ { split( $2, ary, /\#/ ); print ary[1] }' $_tmpf )
        nic_boottypes[$n]=$( awk -F= '/BootProto/ { print $2 }' $_tmpf )
        # get MAC and Link State from hwinventory
        racadm $NODE hwinventory ${nic_keys[$n]} > $_tmpf
        mac_addrs[$n]=$( awk '/^Current MAC Address:/ { print $NF }' $_tmpf )
        link_state[$n]=$( awk '
            /^Link Speed:/ { 
                lspeed = match( $3, /[0-9]/ )
                if ( lspeed > 0 ) { print "UP" }
                else { print "DOWN" }
            }' $_tmpf )
        proto=${nic_boottypes[$n]}
        [[ -z "$proto" ]] && proto="undef"
        echo "$n ${nic_keys[$n]} ${link_state[$n]} ${mac_addrs[$n]} ${proto}"
    done
    rm $_tmpf
}
