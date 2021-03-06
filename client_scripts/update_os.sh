#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=$( dirname "$0" )
PRG="$0"
LIB=$BASE/libs
TS=$( date +%s )
DEFAULT_ENABLED_REPOS=(
    centosplus \
    extras \
    updates \
    base \
    epel \
)

# Import libs
imports=( logging cron puppet csv )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


save_state() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _fn_state _name _value
    _fn_state="$BASE/state"
    _name=$1
    if [[ $# -gt 1 ]] ; then
        _value="$2"
    else
        _value="${!_name}"
    fi
    >>"$_fn_state" echo "${_name}=\"${_value}\""
}


restore_state() {
    [[ $DEBUG -eq $YES ]] && set -x
    fn_state="$BASE/state"
    [[ -f "$fn_state" ]] && {
        source "$fn_state"
        rm "$fn_state"
    }
}


initialize() {
    [[ $DEBUG -eq $YES ]] && set -x
    restore_state
    let "ITERATION=$ITERATION + 1"
    save_state ITERATION
    rm_cron "$PRG"
}


failed_at() {
    # Set FAILED_AT variable, Update and save state for FAILURE_HISTORY
    [[ $DEBUG -eq $YES ]] && set -x
    FAILED_AT="$1"
    FAILURE_HISTORY="$FAILURE_HISTORY $FAILED_AT"
    save_state FAILURE_HISTORY
}


fail_after_too_many_attempts() {
    # TODO - this could be improved by checking how many times the current
    #        value for FAILED_AT exists in FAILURE_HISTORY
    #        ... instead of comparison to reboot count (ie: ITERATION)
    [[ $DEBUG -eq $YES ]] && set -x
    _msg_parts=( "$FAILURE_HISTORY" "$FAILED_AT" )
    [[ $ITERATION -gt $MAX_RETRIES ]] && {
        croak "Failing after '$ITERATION' attempts: Failure History: '$FAILURE_HISTORY'"
    }
}


stop_puppet() {
    # First, get current state of puppet agent
    #     NOTE: Don't overwrite variables if already set ...
    #           on a second run, they will have been saved from first run
    # Second: ensure puppet is stopped
    [[ $DEBUG -eq $YES ]] && set -x
    is_safe_to_proceed || return 1
    [[ -z "$PUP_ENSURE_STATE" ]] && {
        PUP_ENSURE_STATE=$( get_puppet_ensure_state )
        save_state PUP_ENSURE_STATE
    }
    [[ -z "$PUP_ENABLE_STATE" ]] && {
        PUP_ENABLE_STATE=$( get_puppet_enable_state )
        save_state PUP_ENABLE_STATE
    }
    puppet_agent_stop || {
        failed_at "puppet_agent_stop"
        try_again_after_reboot
    }
    puppet_agent_disable || {
        failed_at "puppet_agent_disable"
        try_again_after_reboot
    }
}


restore_puppet() {
    [[ $DEBUG -eq $YES ]] && set -x
    is_safe_to_proceed || return 1
    set_puppet_enable_state $PUP_ENABLE_STATE || {
        failed_at "set_puppet_enable_state"
        try_again_after_reboot
    }
    if [[ $FORCE_REBOOT -eq $NO ]] && [[ $REBOOT_REQUIRED -eq $NO ]] ; then
        # Start puppet only if NOT rebooting
        set_puppet_ensure_state $PUP_ENSURE_STATE || {
            failed_at "set_puppet_ensure_state"
            try_again_after_reboot
        }
    fi
}


is_safe_to_proceed() {
    [[ $DEBUG -eq $YES ]] && set -x
    [[ -z "$FAILED_AT" ]]
}


try_again_after_reboot() {
    [[ $DEBUG -eq $YES ]] && set -x
    REBOOT_REQUIRED=$YES
    mk_cron "$PRG" '@reboot'
}


disable_gpfs() {
    [[ $DEBUG -eq $YES ]] && set -x
    systemctl | grep -q gpfs && systemctl disable gpfs
}


enable_gpfs() {
    [[ $DEBUG -eq $YES ]] && set -x
    is_safe_to_proceed || return 1
    # Attempt only if gpfs is installed
    systemctl | grep -q gpfs && systemctl enable gpfs
}


stop_gpfs() {
    [[ $DEBUG -eq $YES ]] && set -x
    is_safe_to_proceed || return 1
    local _fn_unmount_script
    _fn_unmount_script="$BASE/gpfs_unmount.sh"
    [[ -f $_fn_unmount_script ]] || croak "No such file '$_fn_unmount_script'"
    [[ -x $_fn_unmount_script ]] || croak "Not executable '$_fn_unmount_script'"
    $_fn_unmount_script || {
        failed_at "gpfs_unmount"
        disable_gpfs #should ensure successful gpfs unmount after reboot
        try_again_after_reboot
    }
}


kernel_was_upgraded() {
    local _yum_kernel _rpm_kernel _cur_kernel
    _yum_kernel=$(
        awk '/Installed: kernel-[0-9]/ {print $NF}' /var/log/yum.log \
        | tail -1 )
    _rpm_kernel=$(
        rpm -qa --qf '%{INSTALLTIME} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
        | egrep 'kernel-[0-9]' \
        | sort -n \
        | tail -1 \
        | awk '{print $NF}' )
    _cur_kernel=kernel-$( uname -r )
    log "Yum log kernel: $_yum_kernel"
    log "Newest RPM ker: $_rpm_kernel"
    log "Current kernel: $_cur_kernel"
    [[ -z $_yum_kernel ]] && _yum_kernel=$_cur_kernel #set default if empty
    [[ -z $_rpm_kernel ]] && _rpm_kernel=$_cur_kernel #set default if empty
    [[ "$_cur_kernel" != "$_yum_kernel"  ||  "$_cur_kernel" != "$_rpm_kernel" ]]
}


apply_updates() {
    [[ $DEBUG -eq $YES ]] && set -x
    is_safe_to_proceed || return 1
    local _tmpfn _rc
    
    /usr/bin/yum ${ENABLED_REPOS[@]/#/--enablerepo=} clean all
    rm -rf /var/cache/yum
   
    _tmpfn="$BASE/os_update-${TS}.log"
    &>$_tmpfn /usr/bin/yum \
    ${ENABLED_REPOS[@]/#/--enablerepo=} \
    ${DISABLED_REPOS[@]/#/--disablerepo=} \
    ${DISABLED_PKGS[@]/#/--exclude=} \
    -y \
    upgrade || {
        failed_at "yum_upgrade"
        fail_after_too_many_attempts
        try_again_after_reboot
    }

    if kernel_was_upgraded ; then
        REBOOT_REQUIRED=$YES
    fi
}


reboot() {
    [[ $REBOOT_ALLOWED -eq $YES ]] || return 0
    if [[ $FORCE_REBOOT -eq $YES ]] || [[ $REBOOT_REQUIRED -eq $YES ]] ; then
        fail_after_too_many_attempts 
        log 'REBOOTING SERVER...'
        /sbin/shutdown -r now
    fi
}


usage() {
  cat <<ENDHERE

$PRG
    Apply OS updates on the node.
    First attempts to shutdown gpfs. If unsuccessful, then disable gpfs, reboot,
    and try again.
    If a new kernel was installed, reboot at the end.

USAGE:
    $PRG [OPTIONS]

OPTIONS:
  -d    Show debug output
  -h    print help message and exit
  -v    show what is happening
  --disable_pkgs  Comma separated list of packages to ignore
  --disable_repos Comma separated list of repos to disable during yum update
  --enable_repos  Comma separated list of repos to enable during yum update
                  Note: this is added to the default list of repos
  --force_reboot  Reboot after yum update, even if kernel was not updated.
                  Default = reboot only if kernel was upgraded
  --no_reboot     Do not reboot for any reason. This option trumps "force_reboot".
                  Default = reboot is allowed
  --no_defaults   Unset the default list of enabled repos

DEFAULTS:
    DEFAULT_ENABLED_REPOS: "${DEFAULT_ENABLED_REPOS[@]}"
ENDHERE
}


# Script variables
let YES=SUCCESS=TRUE=0
let NO=FAIL=FALSE=1
ALLOW_DEFAULTS=$YES
DEBUG=$NO
DISABLED_PKGS=()
DISABLED_REPOS=()
ENABLED_REPOS=()
FAILED_AT=
FORCE_REBOOT=$NO
ITERATION=0
MAX_RETRIES=2
REBOOT_ALLOWED=$YES
REBOOT_REQUIRED=$NO
VERBOSE=$NO

# Process cmdline options
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -d) DEBUG=$YES;;
    -h) usage
        exit 0;;
    -v) VERBOSE=1;;
    --disable_pkgs)
        shift
        DISABLED_PKGS=( $( split_csv "$1" ) )
        ;;
    --disable_repos)
        shift
        DISABLED_REPOS=( $( split_csv "$1" ) )
        ;;
    --enable_repos)
        shift
        ENABLED_REPOS=( $( split_csv "$1" ) )
        ;;
    --force_reboot)
        FORCE_REBOOT=$YES
        ;;
    --no_reboot)
        REBOOT_ALLOWED=$NO
        ;;
    --no_defaults)
        ALLOW_DEFAULTS=$NO
        ;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1
        break;;
  esac
  shift
done

[[ $ALLOW_DEFAULTS -eq $YES ]] && {
    ENABLED_REPOS+=( "${DEFAULT_ENABLED_REPOS[@]}" )
}

echo ALLOW_DEFAULTS="$ALLOW_DEFAULTS"
echo DEBUG="$DEBUG"
echo DISABLED_PKGS="${DISABLED_PKGS[@]}"
echo DISABLED_REPOS="${DISABLED_REPOS[@]}"
echo ENABLED_REPOS="${ENABLED_REPOS[@]}"
echo FAILED_AT= "$FAILED_AT"
echo FORCE_REBOOT="$FORCE_REBOOT"
echo ITERATION="$ITERATION"
echo MAX_RETRIES="$MAX_RETRIES"
echo REBOOT_ALLOWED="$REBOOT_ALLOWED"
echo REBOOT_REQUIRED="$REBOOT_REQUIRED"
echo VERBOSE="$VERBOSE"

initialize

stop_puppet

stop_gpfs

apply_updates

restore_puppet

enable_gpfs

reboot
