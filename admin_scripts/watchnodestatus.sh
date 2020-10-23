#!/bin/bash

MAX_SECS=900

NODE="$1"
if [[ -z "$NODE" ]] ; then
  echo "ERROR Missing node"
  exit 1
fi

trap cleanup INT

cleanup() {
  rm -rf $tmp_1 $tmp_2
  exit
}

get_status_n_time() {
  lsdef "$NODE" -i statustime,status | tail -2 | tac | cut -d= -f2 | tr '\n' ' '
}

tmp_1=$(mktemp)
tmp_2=$(mktemp)

while [[ $SECONDS -lt $MAX_SECS ]] ; do

  get_status_n_time >>$tmp_1

  sort -u $tmp_1 -o $tmp_2

  cat $tmp_2

  mv $tmp_2 $tmp_1

  sleep 5
  echo $SECONDS

done

cleanup
