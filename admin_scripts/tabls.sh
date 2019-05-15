#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs
PRG=$( basename $0 )

# Import libs
imports=( logging )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


usage() {
  cat <<ENDHERE

$PRG
    List non-empty xCAT table names
Usage:
    $PRG [OPTIONS]

OPTIONS:
  -h    print help message and exit
  -a    All tables (by default, ignores known auto-populated tables)

NOTE: Table 'auditlog' will always be ignored.

ENDHERE
}


mk_ignore_list() {
    IGNORE_LIST=( auditlog )
    if [[ $SHOWALL -eq $NO ]] ; then
        IGNORE_LIST+=( 
            bootparams \
            chain \
            discoverydata \
            linuximage \
            mac \
            nodelist \
            nodetype \
            osdistro \
            osimage \
            policy
        )
    fi
}


do_tabls() {
    local _patrn
    _patrn=$( ( IFS='|'; cat <<< "${IGNORE_LIST[*]}" )  )
    for t in $(tabdump | grep -E -v "$_patrn"); do
        c=$(tabdump $t | wc -l)
        [ $c -gt 2 ] && echo $t
    done
}


ENDWHILE=0
SHOWALL=$NO
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
  case $1 in
    -h) usage
        exit 0;;
    -a) SHOWALL=$YES;;
    --) ENDWHILE=1;;
     *) ENDWHILE=1; break;;
  esac
  shift
done

mk_ignore_list

do_tabls
