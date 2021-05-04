#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

# Define global variables.
BASE=/root/xcat-tools
LIB=$BASE/libs
PROGRAM=$( basename $0 )
NODELIST=""
NODELISTEXPLODED=""
NEWPASSWORD=""
NUMPROBLEMNODES=0
ISPROBLEMNODE=0
PROBLEMNODE_FILE=""
TMPDIR=""
NODE_BRAND=""

# Import libs
imports=( logging backup racadm bmc node build_nodelist )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done
DEBUG=$NO


# Define usage function: print script usage.
usage() {
  cat <<ENDUSAGEHERE

$PROGRAM
    Test, list, or update BMC credentials for xCAT-controlled nodes.

Usage:
    bmc_passwords -h|--help
        Print this message.
    bmc_passwords NODELIST
        Standard mode: explode NODELIST, categorize by brand of
        server, test BMC connections, then list all nodes with brand
        and status.
    bmc_passwords -l NODELIST
        List mode: skip connection test and list in verbose mode,
        including IP address, username, and password along with
        name and brand.
    bmc_passwords -u NEWPASSWORD NODELIST
        Update mode: change password on each BMC and add/update
        node-level entry in the xCAT ipmi table. You may want to
        put NEWPASSWORD in parentheses.

ENDUSAGEHERE
} # End function 'usage'


# Define prep_output_files function: create a tmpdir and PROBLEMNODE_FILE.
prep_output_files() {
  TMPDIR=$( mktemp -d )
  PROBLEMNODE_FILE=$TMPDIR/problem_nodes
} # End function 'prep_output_files'


clean_output_files() {
  if [[ $NUMPROBLEMNODES -lt 1 ]]; then
    rm -rf $TMPDIR
  else
    echo ""
    echo "Per-node output in: $TMPDIR"
    echo ""
  fi
}


# Define explode_nodelist function: expand the nodelist into a list of individual nodes, one per line.
explode_nodelist() {
  NODELISTEXPLODED=( $( build_nodelist "$NODELIST" ) )
}


# Define confirm_proceed_with_update function: show the user the number of nodes that will be affected
#   and show them the password that has been input, as parsed by the script. Prompt to see if they
#   want to continue and if not, abort.
confirm_proceed_with_update() {
  num_nodes=$( echo "${NODELISTEXPLODED[@]}" | wc -w )
  echo
  echo "  You are about to change the BMC password for $num_nodes nodes."
  echo "  You have specified $NEWPASSWORD as the new password."
  read -p "  Are you sure you'd like to proceed (y/n)? " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo
    echo "Aborting $PROGRAM script."
    echo
    exit 0
  fi
}


# Define backup_ipmi_table function: backup the xCAT ipmi table to a unique location and tell the
#   user where it is; if the base backup dir (currently ZFS does not exist), abort.
backup_ipmi_table() {
  local _bkup_fn="/root/bkup-ipmi-dbtable.$TIMESTAMP"
  echo "  Backing up the xCAT ipmi table to $_bkup_fn ..."
  tabdump -f $_bkup_fn ipmi
}


# Define reset_is_problem_node fuction: sets ISPROBLEMNODE to 0 (used when evaluating a new node).
reset_is_problem_node() {
  ISPROBLEMNODE=0
} # End function 'reset_is_problem_node'


# Define increment_num_problem_nodes function: increments NUMPROBLEMNODES, but only if this node
#   has not been counted yet. 
increment_num_problem_nodes() {
  if [[ $ISPROBLEMNODE -eq 0 ]]; then
    let "NUMPROBLEMNODES++"
    ISPROBLEMNODE=1
    echo $node >> $PROBLEMNODE_FILE
  fi
} # End function 'increment_num_problem_nodes'


node_has_bmc_data() {
  local _wordcount=$( get_bmc_ip_user_pass "$node" | wc -w )
  local _rv=$OK
  [[ $_wordcount -eq 3 ]] || {
    warn "incomplete bmc data for node '$node'"
    increment_num_problem_nodes
    _rv=$ERR
  }
  return $_rv
}


is_valid_node_brand() {
  local _is_dell _is_lenovo _brand_sum
  local _rv=$ERR
  _is_dell=$( lsdef $node -i groups | grep groups= | egrep '=dell|,dell' | wc -l )
  _is_lenovo=$( lsdef $node -i groups | grep groups= | egrep '=lenovo|,lenovo' | wc -l )
  _brand_sum=$(($_is_dell + $_is_lenovo))
  if [[ $_brand_sum -ne 1 ]] ; then
    warn "cant determine node brand"
    increment_num_problem_nodes
  elif [[ $_is_dell -eq 1 ]]; then
    NODE_BRAND="Dell"
    _rv=$OK
  elif [[ $_is_lenovo -eq 1 ]]; then
    NODE_BRAND="Lenovo"
    _rv=$OK
  fi
  return $_rv
}


# Define report_problem_nodes function: indicate number of problem nodes and, if there were any,
#   the location of the PROBLEMNODE_FILE.
report_problem_nodes() {
  echo ""
  echo "total problem nodes: $NUMPROBLEMNODES"
  if [[ $NUMPROBLEMNODES -ne 0 ]]; then
    echo -n "  list of problem nodes: "
    cat "$PROBLEMNODE_FILE"
  fi
}


check_connection() {
  if [[ $NODE_BRAND == "Lenovo" ]]; then
    check_connection_lenovo
  elif [[ $NODE_BRAND == "Dell" ]]; then
    check_connection_dell
  fi
}


check_connection_lenovo() {
  local _rv=$ERR
  local _ip _usr _pwd
  echo "  check connection Lenovo ..."
  [[ -x /opt/lenovo/toolscenter/asu/asu64 ]] || croak "asu64 not found"
  read -r _ip _usr _pwd <<<$( get_bmc_ip_user_pass "$node" )
  # TODO - make ASU an external function
  &>> $node_logfile /opt/lenovo/toolscenter/asu/asu64 \
    show IMM.LoginId.1 \
    --host "$_ip" \
    --user "$_usr" \
    --password "$_pwd"
  if [[ -n $( grep IMM.LoginId.1= $node_logfile ) ]] ; then
    echo "  connection successful!"
    _rv=$OK
  fi
  return $_rv
}


check_connection_dell() {
  local _rv=$ERR
  echo "  check connection Dell ..."
  racadm "$node" "get iDRAC.Users.2.UserName" &>> $TMPDIR/$node
  if [[ -n $( grep UserName= $node_logfile ) ]]; then
    echo "  connection successful!"
    _rv=$OK
  else
    echo "  connection failed, please investigate!"
    increment_num_problem_nodes
  fi
  return $_rv
}


list_node_info() {
  local _ip _usr _pwd
  read -r _ip _usr _pwd <<<$( get_bmc_ip_user_pass "$node" )
  echo "  ip=$_ip"
  echo "  username=$_usr"
  echo "  password=$_pwd"
}


update_node() {
  if [[ $NODE_BRAND == "Lenovo" ]]; then
    update_node_lenovo
  elif [[ $NODE_BRAND == "Dell" ]]; then
    update_node_dell
  fi
}


update_node_lenovo() {
  local _rv=$ERR
  local _ip _usr _pwd
  echo "  update node Lenovo ..."
  [[ -x /opt/lenovo/toolscenter/asu/asu64 ]] || croak "asu64 not found"
  read -r _ip _usr _pwd <<<$( get_bmc_ip_user_pass "$node" )
  # TODO - make ASU an external function
  &>>$node_logfile /opt/lenovo/toolscenter/asu/asu64 \
    set IMM.Password.1 "$NEWPASSWORD" \
    --host "$_ip" \
    --user "$_usr" \
    --password "$_pwd"
  if [[ -n $( grep "Command completed successfully." $node_logfile ) ]]; then
    _rv=$OK
    echo "" >> $node_logfile
    echo "" >> $node_logfile
    &>> $node_logfile chdef -t node -o $node bmcpassword="$NEWPASSWORD"
    echo "  password change successful!"
  else
    echo "  password change FAILED, please investigate!"
    increment_num_problem_nodes
  fi
  return $_rv
}


update_node_dell() {
  local _rv=$ERR
  echo "  update node Dell ..."
  &>>$node_logfile racadm "$node" "set iDRAC.Users.2.Password $NEWPASSWORD"
  if [[ -n $( grep "Object value modified successfully" $node_logfile ) ]]; then
    _rv=$OK
    echo "  password changed successful!"
    echo "" >> $node_logfile; echo "" >> $node_logfile
    chdef -t node -o "$node" bmcpassword="$NEWPASSWORD" &>> $node_logfile
  else
    echo "  password change FAILED, please investigate!"
    increment_num_problem_nodes
  fi
  return $_rv
}


[[ ! -t 0 ]] && croak "must be run interactively" # stdin is NOT running in a terminal

# Process parameters
LIST_NODE_INFO=$NO
CHECK_CONNECTION=$NO
UPDATE_NODE=$NO
case $1 in
  -h|--help)
    usage
    exit 0
    ;;
  -l)
    LIST_NODE_INFO=$YES
    shift
    [[ $# -eq 1 ]] || croak "incorrect number of parameters, please run with -h for usage"
    ;;
  -u)
    UPDATE_NODE=$YES
    CHECK_CONNECTION=$YES
    NEWPASSWORD="$2"
    shift 2
    [[ $# -eq 1 ]] || croak "incorrect number of parameters, please run with -h for usage"
    ;;
  *)
    [[ $# -eq 1 ]] || croak "incorrect number of parameters, please run with -h for usage"
    CHECK_CONNECTION=$YES
    ;;
esac
NODELIST="$1"
[[ -z "$NODELIST" ]] && croak "empty nodelist"

prep_output_files

explode_nodelist

if [[ $UPDATE_NODE -eq $YES ]] ; then
  confirm_proceed_with_update
  backup_ipmi_table
fi 

echo "TMPDIR=$TMPDIR"

for node in "${NODELISTEXPLODED[@]}"; do
  echo "$node"
  reset_is_problem_node
  is_valid_node_brand || continue
  node_has_bmc_data || continue
  node_logfile="$TMPDIR/$node"

  [[ $LIST_NODE_INFO -eq $YES ]] && list_node_info

  if [[ $CHECK_CONNECTION -eq $YES ]] ; then
    check_connection || {
      increment_num_problem_nodes
      continue
    }
  fi

  if [[ $UPDATE_NODE -eq $YES ]] ; then
    update_node && {
      echo "  YAY" 
    } || {
      echo "  OOPS" 
      increment_num_problem_nodes
      continue
    }
  fi
done

report_problem_nodes

clean_output_files
