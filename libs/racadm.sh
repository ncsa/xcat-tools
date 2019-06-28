racadm() {
    [[ $DEBUG -eq $YES ]] && set -x
    # eval defines variables: bmc, bmcusername, bmcpassword
    # as returned by the xCAT table "ipmi"
    eval $( lsdef -t node -o $1 -i bmc,bmcpassword,bmcusername | tail -n+2 )
    shift
    export SSHPASS="$bmcpassword"
    sshpass -e ssh -l $bmcusername $bmc -- racadm "$*" | grep -v 'efault \(user\|password\)'
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


_sleep(){
    printf 'Waiting 120 seconds for iDRAC reboot'
    for i in $(seq 12); do 
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
    | while read; do
        cmdparts=("$NODE" jobqueue create "$REPLY")
        log "racadm ${cmdparts[@]}"
        output=$( racadm "${cmdparts[@]}" )
        check_racadm_output "$output" "attempt to '${cmdparts[*]}'"
    done
    output=$( racadm $NODE serveraction hardreset )
    check_racadm_output "$output" "attempt to serveraction hardreset"
    _sleep
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
