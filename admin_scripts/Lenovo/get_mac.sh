#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs

# Import libs
imports=( logging build_nodelist )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done

nodelist=( build_nodelist "$@" )

for n in "${nodelist[@]}"; do
    mac=$( rinv "$n" mac | awk '/: MAC Address 1:/ {print $NF}' )
    if [[ ${#mac} -ne 17 ]]; then
        echo "Skipping invlid mac '$mac' for node '$n'"
        continue
    fi
    set -x
    nodech "$n" mac.mac="$mac"
    set +x
done
