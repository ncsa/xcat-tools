#!/bin/bash

# SVCPLAN-5154: Dell firmware version check
# Takes a node range as input, and uses racadm to list out hardware type, bios version and iDRAC version.

racadmpath=/root/xcat-tools/admin_scripts/Dell/racadm.sh

# If user does not provide a node range, prompt them for one here. Invalid entries will cause the script to run against all nodes.
if [ -z "$1" ]; then
  read -p "Please enter a node range: " RANGE
else
  RANGE=$1
fi

# Assign the node range into an array to loop through
readarray -t ARRAY < <(nodels $RANGE)

# Find longest node name for dynamic width formatting
max=-1
for i in "${ARRAY[@]}"
  do
    len=${#i}
    ((len > max)) && max=$len
done

# Print table headers with formatting
printf "Running scan on noderange: $RANGE \n"
printf "%*s %10s %-15s %-19s %-20s \n" "$max" "Node" ""  "Bios" "iDRAC" "Model"
printf "__________________________________________________________________________\n"

for i in "${ARRAY[@]}"
do
  # Run racadm <node> getversion and pull bios & iDRAC versions. Store these into a temp array for formatting.
  readarray -t TEMP < <(timeout 15 /bin/bash $racadmpath $i getversion | egrep -i 'bios|idrac' | sort -V | awk '{print $NF}' | head -n 2)

  printf "%*s %10s %-15s %-15s" "$max" "$i" "" "${TEMP[0]}" "${TEMP[1]}"
  printf "%-5s"

  # Pull hardware model number through dmidecode, and filter out "Poweredge" out of model name.
  model=$(timeout 15 ssh $i dmidecode -s system-product-name | awk '{ print $2 }')

  # If the above command times out, print that it timed out
  if [ -z "$model" ]; then
    printf "Timed Out \n"
  else
    printf "%s \n" "$model"
  fi

done
