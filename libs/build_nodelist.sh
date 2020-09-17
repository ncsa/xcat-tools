build_nodelist() {
    ### Build nodelist from parameters
    local NODELS=/opt/xcat/bin/nodels
    if [[ $# -lt 1 ]] ; then
        croak "Empty nodelist"
    elif [[ $# -eq 1 ]] ; then
        nodelist=( $( $NODELS $1 ) )
    else
        nodelist=( $( for a in $*; do $NODELS $a; done ) )
    fi
    echo "${nodelist[@]}"
}
