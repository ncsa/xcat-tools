#!/bin/bash
#
# SVCPLAN-5539: IB network performance test
# Checks the InfiniBand bandwidths between a group of nodes using the ib_read_bw command
#
########################### Parameters ##########################################
#
# Parameters can be defined through the use of flags, or sourced from a configuration file with the -c flag
#
# -h, HOST	A designated host that a node range will test IB performance
#
# -t, TARGET	If testing requires targeting a specific receiver on HOST, can use this parameter to specify
#
# -r, RANGE	An xCAT group or noderange to test IB performance against
#
# -v, VALUE	A threshold value (MB/sec) of expected performance. Can be used to filter results to show only underperforming nodes
#
# -d, DEV	Use IB device <dev> (default first device found)
#
# -p, PORT	Listen on/connect to port <port> (default is 18515)
#
# -s, SIZE	Size of message to exchange (default 65536)
#
# -c		Sources a configuration file which is a set of predefined parameters. Recommended for testing different setups with ease.
#		For more details on using configuration files, refer to xcat-tools/conf/ib_performance.conf.example
#
################################################################################

# Parse parameters 
flag_params=""
HOST=test001
TARGET=""
RANGE=test
VALUE=10000

while getopts h:t:r:v:d:p:s:c: opt; do
  case ${opt} in
    h) HOST=${OPTARG};;
    t) TARGET=${OPTARG};;
    r) RANGE=${OPTARG};;
    v) VALUE=${OPTARG};;
    d) DEV=${OPTARG};;
    p) PORT=${OPTARG};;
    s) SIZE=${OPTARG};;
    c) source "${OPTARG}";;
  esac
done

if [[ -z "$TARGET" ]]; then
  TARGET=$HOST
fi

if [[ -n "${PORT}" ]]; then
  flag_params+=" -p $PORT"
fi
if [[ -n "${SIZE}" ]]; then
  flag_params+=" -s $SIZE"
fi

host_params=$flag_params
node_params=$flag_params

if [[ -n "${DEV}" ]]; then
  node_params+=" -d $DEV"
fi

# Declare parameters (useful when using configuration files)
printf "Starting IB performance test.\n"
printf "Host is %s\n" "$HOST"
printf "Range is %s\n" "$RANGE"
printf "Desired Performance is %s\n\n" "$VALUE"

# Assign node range into array to loop through (if the host is also in the node range, exclude it)
readarray -t ARRAY < <(nodels $RANGE,-$HOST)

# Each element in the array is a new node in the provided node range
for i in "${ARRAY[@]}"
do
  # Start a server and wait for an IB connection on the host node
  ssh $HOST timeout 60 ib_read_bw -a $host_params >/dev/null &
  sleep 1  

  # Make connection and filter results for final speed (MB/s)
    SPEED=`ssh $i ib_read_bw -a $node_params $TARGET 2>/dev/null | tail -n 2 | head -n 1 | awk '{print $4}'`

  printf "Testing connection from %s to %s\n" "$TARGET" "$i" 
  # Error message if no SPEED is reported (likely connection failed)
  if [[ -z "${SPEED}" ]]; then
    printf "Error: 	IB connection failed to node %s\n" "$i"
  # Warning if reported speed is below desired threshold value
  elif (( ${SPEED%.*} < $VALUE )); then
    printf "Warning:	%s ran at %s (%s expected)\n" "$i" "$SPEED" "$VALUE"
  fi
done
