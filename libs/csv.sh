split_csv() {
    [[ $DEBUG -eq $YES ]] && set -x
    echo "$1" | awk -F, '{for (i=1;i<=NF;++i) {print $i}}'
}
