mk_cron() {
    [[ $DEBUG -eq 0 ]] && set -x
    local _cronscript _schedparts _fn _tmpfn
    _cronscript="$1"
    shift
    _schedparts=( "${@}" )
    [[ -x "$_cronscript" ]] || die "Cronscript '$_cronscript' is not executable."
    _fn=$( basename "$_cronscript" )
    _tmpfn=$(mktemp)
    >$_tmpfn crontab -l
    # if not already present, then add it
    grep -q -F "$_fn" $_tmpfn || {
        >>$_tmpfn echo "${_schedparts[@]} $_cronscript"
        crontab $_tmpfn
    }
    rm -f $_tmpfn
}


rm_cron() {
    [[ $DEBUG -eq 0 ]] && set -x
    local _cronscript _fn _tmpfn
    _cronscript="$1"
    shift
    _fn=$( basename "$_cronscript" )
    _tmpfn=$(mktemp)
    >$_tmpfn crontab -l
    # if not already present, then add it
    grep -q -F "$_fn" $_tmpfn && {
        grep -v -F "$_fn" $_tmpfn | crontab -
    }
    rm -f $_tmpfn
}
