continue_or_exit() {
    local msg="Continue?"
    [[ -n "$1" ]] && msg="$1"
    echo "$msg" 1>&2
    select yn in "Yes" "No"; do
        case $yn in
            Yes) return 0;;
            No ) exit 1;;
        esac
    done
}

ask_yes_no() {
    local rv=1
    local msg="Is this ok?"
    [[ -n "$1" ]] && msg="$1"
    echo "$msg" 1>&2
    select yn in "Yes" "No"; do
        case $yn in
            Yes) rv=0;;
            No ) rv=1;;
        esac
        break
    done
    return $rv
}
