#!/bin/bash

#DEBUG=1
GPFSBIN=/usr/lpp/mmfs/bin
GPFSCONF=/var/mmfs/etc


die() {
    echo "ERROR: $*" 1>&2
    exit 99
}


debug() {
    [[ $DEBUG -eq 1 ]] || return 0
    echo "DEBUG: $*"
}


clean_exit() {
    echo "$*"
    exit 0
}


is_gpfs_installed() {
    [[ $DEBUG -eq 1 ]] && set -x
    [[ -d $GPFSBIN ]]
}


get_gpfs_state() {
    [[ $DEBUG -eq 1 ]] && set -x
    $GPFSBIN/mmgetstate | grep `hostname -s` | awk '{print $NF}'
}


are_kernel_modules_loaded() {
    [[ $DEBUG -eq 1 ]] && set -x
    [[ $(lsmod | grep mmfs | wc -l) -gt 0 ]]
}


is_gpfs_stopped() {
    [[ $DEBUG -eq 1 ]] && set -x
    # Return quickly if modules are not loaded
    are_kernel_modules_loaded || return 0
    cur_state=$( get_gpfs_state )
    # stopped?
    local stopped=1
    if [[ -z "$cur_state" ]] ; then
        stopped=0
    elif [[ "$cur_state" == "down" ]] ; then
        stopped=0
    fi
    # modules?
    ! are_kernel_modules_loaded
    local modules=$?
    # result
    local rc
    let "rc = $stopped + $modules"
    return $rc
}

is_gpfs_running() {
    ! is_gpfs_stopped
}


get_gpfs_mounts() {
    [[ $DEBUG -eq 1 ]] && set -x
    mount -t gpfs | awk '{print $3}'
}


get_bindmounts() {
    [[ $DEBUG -eq 1 ]] && set -x
    awk '
        NR==FNR { gpfs_mounts[$1]++; next }
        /bind/ { if ( gpfs_mounts[$2] > 0 ) { print $2 } }
    ' <( get_gpfs_mounts ) /etc/fstab
}


gpfs_off() {
    # Attempt to turn off / shutdown gpfs
    # This will unmount all native gpfs mounts (but not bindmounts)
    # Return 0 on success, non-zero otherwise
    [[ $DEBUG -eq 1 ]] && set -x
    $GPFSBIN/mmshutdown
    sleep 10
    is_gpfs_stopped
}


ls_procs() {
    # List all unique process IDs that are accessing files on any gpfs mountpoint
    [[ $DEBUG -eq 1 ]] && set -x
    get_gpfs_mounts | xargs -r -n1 lsof -t | sort -ur
}


kill_procs() {
    # Attempt to kill processes accessing files on gpfs
    [[ $DEBUG -eq 1 ]] && set -x

    #try HUP first
    ls_procs | xargs -r -- kill
    [[ $( ls_procs | wc -l ) -gt 0 ]] && sleep 5

    #if anything left, send KILL
    ls_procs | xargs -r -- kill -9
    [[ $( ls_procs | wc -l ) -gt 0 ]] && sleep 5

    #return 0 if no procs remain, non-zero otherwise
    return $( ls_procs | wc -l )
}


[[ $DEBUG -eq 1 ]] && set -x

# Exit quickly if no GPFS
is_gpfs_installed || {
    clean_exit "GPFS not found. Exiting."
}


if is_gpfs_running; then

    # Kill any processes still using files in GPFS
    kill_procs || die "Filesystem still busy. Attempt to kill processes was unsuccessful"

    # Attempt to unmount all bind mounts
    # Sometimes, multiple bind mounts are present,
    # keep looking until bind mount count == 0
    # If mount count doesn't change after 2 attempts, exit with an error
    bind_mounts=( $( get_bindmounts ) )
    debug "GPFS BIND MOUNTS"
    debug "${bind_mounts[@]}"
    repeat_attempts=0
    while [[ ${#bind_mounts[*]} -gt 0 ]] ; do
        debug "Attempt to unmount '${#bind_mounts[*]}' bind mounts"
        echo "${bind_mounts[@]}" | xargs -r /bin/umount
        prev_mcount=${#bind_mounts[*]}
        bind_mounts=( $( get_bindmounts ) )
        debug "Current bind mounts: '${mounts_curr[@]}'"
        if [[ ${#bind_mounts[*]} -lt $prev_mcount ]] ; then
            debug "resetting attempts counter"
            repeat_attempts=0
        else
            debug "mount count didn't decrease, trying again"
            let "repeat_attempts+=1"
        fi
        [[ $repeat_attempts -ge 2 ]] && die "Unable to unmount some bind mounts"
    done

    debug "SHUTDOWN GPFS"
    gpfs_off || die "GPFS shutdown was unsuccessful"

fi
clean_exit
