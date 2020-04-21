#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs


# Import libs
imports=( logging racadm node bmc )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done


# exit 0 if key is set/enabled
# exit 1 if key is disabled
# exit 2 if key is not found
get_bool() {
  node=$1
  key=$2
  racadm $node get "$key" \
  | awk -F '=' '
BEGIN { retval=2 }
$NF ~ /Enabled/ { retval=0 }
$NF ~ /Disabled/ { retval=1 }
END { exit retval }
'
}


set_bool() {
  node=$1
  key=$2
  val=$3
  racadm $node set "$key" "$val"
}

VALS=( $( seq -w 01 16 ) )
for i in "${VALS[@]}"; do
  node="verify-worker${i}-srvc"
  echo $node
  get_bool $node 'iDRAC.IPMILan.Enable'
  rc=$?
  check_again=0
  if [[ $rc -eq 0 ]]; then
    echo "OK"
  elif [[ $rc -eq 1 ]]; then
    echo "ipmi lan OFF"
    set_bool $node 'iDRAC.IPMILan.Enable' 1
    check_again=1
  else
    echo "ERROR - unknown racadm key"
  fi
  if [[ $check_again -gt 0 ]]; then
    get_bool $node 'iDRAC.IPMILan.Enable' \
    && echo "OK" \
    || echo "ERROR - Attempt to set didnt work"
  fi
done
