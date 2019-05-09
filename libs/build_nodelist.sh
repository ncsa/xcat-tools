build_nodelist() {
    ### Build nodelist from parameters
    if [[ $# -lt 1 ]] ; then
        croak "Empty nodelist"
    elif [[ $# -eq 1 ]] ; then
        nodelist=( $( nodels $1 ) )
    else
        nodelist=( $( for a in $*; do nodels $a; done ) )
    fi
    echo "${nodelist[@]}"
}
