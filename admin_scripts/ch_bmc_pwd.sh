#!/bin/bash

# By JDR with some code borrowed from AJL's 'rebuild' and 'mracadm' scripts.

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

# Define global variables.
BASE=___INSTALL_DIR___
LIB=$BASE/libs
PROGRAM=$( basename $0 )
NODELIST=""
NODELISTEXPLODED=""
NEWPASSWORD=""
NUMPROBLEMNODES=0
ISPROBLEMNODE=0
PROBLEMNODE_FILE=""

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
  tmpdir=$( mktemp -d )
  PROBLEMNODE_FILE=$tmpdir/problem_nodes
} # End function 'prep_output_files'


# Define explode_nodelist function: expand the nodelist into a list of individual nodes, one per line.
explode_nodelist() {
  NODELISTEXPLODED=( $( nodels $NODELIST ) )
} # End function 'explode_nodelist'


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
  backup_suffix=$( echo $tmpdir | cut -d/ -f3 | cut -d. -f2 )
  backup_date=$( date +%Y%m%d )
  backup_dir=/backup/$backup_date
  if [[ ! -d $backup_dir ]]; then
    croak "backup_dir $backup_dir does not exist, canceling execution"
  fi
  backup_timestamp=$( date +%s )
  backup_file=$backup_dir/ipmi_table_backup-$backup_timestamp-$backup_suffix
  echo
  echo "  Backing up the xCAT ipmi table to $backup_file ..."
  tabdump -f $backup_file ipmi
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


# Define gather_bmc_info function: gather IP and credentials for the BMC from xCAT.
gather_bmc_info() {
  bmc_ip=$( lsdef -t node $node -i bmc | grep bmc= | cut -d= -f2 )
  bmc_username=$( lsdef -t node $node -i bmcusername | grep bmcusername= | cut -d= -f2 )
  bmc_password=$( lsdef -t node $node -i bmcpassword | grep bmcpassword= | cut -d= -f2 )
}


# Define validate_bmc_info_or_skip_node function: check BMC IP and credentials, and 'continue'
#   to next loop iteration, skipping the node, if any of them are not present (also flag it).
#   Used for standard and update modes.
validate_bmc_info_or_skip_node() {
    if [[ -z $bmc_ip ]]; then
      echo "  missing bmc_ip, will not attempt to connect"
      increment_num_problem_nodes
      continue
    fi
    if [[ -z $bmc_username ]]; then
      echo "  missing bmc_username, will not attempt to connect"
      increment_num_problem_nodes
      continue
    fi
    if [[ -z $bmc_password ]]; then
      echo "  missing bmc_password, will not attempt to connect"
      increment_num_problem_nodes
      continue
    fi
}


# Define validate_bmc_info_or_flag_node function: check BMC IP and credentials, and flag node
#   if any of them are not present. Used for list mode.
validate_bmc_info_or_flag_node() {
  if [[ -z $bmc_ip ]] || [[ -z $bmc_username ]] || [[ -z $bmc_password ]]; then
    increment_num_problem_nodes
  fi
}


# Define get_xcat_brand function: get the brand of the node according to xCAT (e.g., Lenovo, Dell).
get_xcat_brand() {
  local mybrand=""
  node_should_be_dell=$( lsdef $node -i groups | grep groups= | egrep '=dell|,dell' | wc -l )
  node_should_be_lenovo=$( lsdef $node -i groups | grep groups= | egrep '=lenovo|,lenovo' | wc -l )
  brand_sum=$(($node_should_be_dell + $node_should_be_lenovo))
  if [[ $brand_sum -ne 1 ]]; then
    mybrand="WARNING"
  elif [[ $node_should_be_dell -eq 1 ]]; then
    mybrand="Dell"
  elif [[ $node_should_be_lenovo -eq 1 ]]; then
    mybrand="Lenovo"
  else
    mybrand="ERROR"
  fi
  echo "$mybrand"
} # End function 'get_xcat_brand'


# Define report_problem_nodes function: indicate number of problem nodes and, if there were any,
#   the location of the PROBLEMNODE_FILE.
report_problem_nodes() {
  echo "  total problem nodes: $NUMPROBLEMNODES"
  if [[ $NUMPROBLEMNODES -ne 0 ]]; then
    echo "  list of problem nodes: $PROBLEMNODE_FILE"
  fi
}


# Define run_standard_mode function: run the appropriate tasks for each node, standard mode.
run_standard_mode() {
  prep_output_files

  echo ""
  echo "$PROGRAM: standard mode: $NODELIST"
  echo "  notice: connection test output can be found in tmpdir: $tmpdir"
  echo ""

  explode_nodelist

  for node in "${NODELISTEXPLODED[@]}"; do
    echo $node
    reset_is_problem_node

    # Gather info about the node.
    gather_bmc_info
    validate_bmc_info_or_skip_node
    xcat_brand=$(get_xcat_brand)

    # Check brand according to xCAT and test the connection.
    if [[ $xcat_brand == "WARNING" ]]; then
      echo "  WARNING: xCAT is unsure of the brand - please investigate the ipmi table"
      increment_num_problem_nodes
    elif [[ $xcat_brand == "ERROR" ]]; then
      echo "  ERROR: the script ran into a problem determining the brand of $node"
      increment_num_problem_nodes
    else
      echo "  assumed brand=$xcat_brand"
      tmpfile=$tmpdir/$node
      if [[ $xcat_brand == "Lenovo" ]]; then
        /opt/lenovo/toolscenter/asu/asu64 show IMM.LoginId.1 --host $bmc_ip \
          --user $bmc_username --password "$bmc_password" &>> $tmpfile
        if [[ -n $( grep IMM.LoginId.1= $tmpfile ) ]]; then
	  echo "  connection successful!"
        else
	  echo "  connection failed, please investigate!"
          increment_num_problem_nodes
        fi
      elif [[ $xcat_brand == "Dell" ]]; then
        /opt/dell/srvadmin/sbin/racadm-wrapper-idrac7 -r $bmc_ip -u $bmc_username \
          -p "$bmc_password" get iDRAC.Users.2.UserName &>> $tmpdir/$node
        if [[ -n $( grep UserName= $tmpfile ) ]]; then
          echo "  connection successful!"
        else
          echo "  connection failed, please investigate!"
          increment_num_problem_nodes
        fi
      fi
    fi
  done

  echo ""
  echo "$PROGRAM: standard mode: all done!"
  report_problem_nodes
  echo "  reminder: connection test output can be found in tmpdir: $tmpdir"
  echo ""
} # End function 'run_standard_mode'


# Define run_list_mode function: run the appropriate tasks for each node, list mode.
run_list_mode() {
  prep_output_files

  echo ""
  echo "$PROGRAM: list mode: $NODELIST"
  echo ""

  explode_nodelist

  for node in "${NODELISTEXPLODED[@]}"; do
    echo $node
    reset_is_problem_node

    # Gather info about the node.
    gather_bmc_info
    validate_bmc_info_or_flag_node
    xcat_brand=$(get_xcat_brand)

    # Create output.
    echo "  ip=$bmc_ip"
    echo "  username=$bmc_username"
    echo "  password=$bmc_password"
    if [[ $xcat_brand == "WARNING" ]]; then
      echo "  WARNING: xCAT is unsure of the brand - please investigate the ipmi table"
      increment_num_problem_nodes
    elif [[ $xcat_brand == "ERROR" ]]; then
      echo "  ERROR: the script ran into a problem determining the brand of $node"      
      increment_num_problem_nodes
    else
      echo "  assumed brand=$xcat_brand"
    fi
  done

  echo ""
  echo "$PROGRAM: list mode: all done!"
  report_problem_nodes
  if [[ ! "$( ls -A $tmpdir )" ]]; then
    rm -rf $tmpdir
  fi
  echo ""
} # End function 'run_list_mode'


# Define run_update_mode function: run the appropriate tasks for each node, update mode.
run_update_mode() {
  prep_output_files

  echo
  echo "$PROGRAM: update mode: $NODELIST"
  echo "  notice: detailed asu64/racadm output can be found in tmpdir: $tmpdir"

  explode_nodelist
  confirm_proceed_with_update
  backup_ipmi_table

  for node in "${NODELISTEXPLODED[@]}"; do
    echo $node
    reset_is_problem_node

    # Gather info about the node.
    gather_bmc_info
    validate_bmc_info_or_skip_node
    xcat_brand=$(get_xcat_brand)

    # If the node is uniquely branded according to xCAT, attempt to update the BMC password.
    if [[ $xcat_brand == "WARNING" ]]; then
      echo "  WARNING: xCAT is unsure of the brand - please investigate the ipmi table"
      increment_num_problem_nodes
    elif [[ $xcat_brand == "ERROR" ]]; then
      echo "  ERROR: the script ran into a problem determining the brand of $node"
      increment_num_problem_nodes
    else
      echo "  assumed brand=$xcat_brand"
      tmpfile=$tmpdir/$node
      if [[ $xcat_brand == "Lenovo" ]]; then
        /opt/lenovo/toolscenter/asu/asu64 set IMM.Password.1 "$NEWPASSWORD" \
          --host $bmc_ip --user $bmc_username --password "$bmc_password" &>> $tmpfile 
        if [[ -n $( grep "Command completed successfully." $tmpfile ) ]]; then
          echo "" >> $tmpfile; echo "" >> $tmpfile
          chdef -t node -o $node bmc=$bmc_ip bmcusername=$bmc_username \
            bmcpassword="$NEWPASSWORD" &>> $tmpfile
          echo "  password change successful!"
        else
          echo "  password change FAILED, please investigate!"
          increment_num_problem_nodes
        fi
      elif [[ $xcat_brand == "Dell" ]]; then
        /opt/dell/srvadmin/sbin/racadm-wrapper-idrac7 -r $bmc_ip -u $bmc_username \
          -p "$bmc_password" set iDRAC.Users.2.Password "$NEWPASSWORD" &>> $tmpfile
        if [[ -n $( grep "Object value modified successfully" $tmpfile ) ]]; then
          echo "" >> $tmpfile; echo "" >> $tmpfile
          chdef -t node -o $node bmc=$bmc_ip bmcusername=$bmc_username \
            bmcpassword="$NEWPASSWORD" &>> $tmpfile
          echo "  password changed successful!"
        else
          echo "  password change FAILED, please investigate!"
          increment_num_problem_nodes
        fi
      fi
    fi
  done

  echo ""
  echo "$PROGRAM: update mode: all done!"
  report_problem_nodes
  echo "  reminder: connection output can be found in tmpdir: $tmpdir"
  echo ""
} # End function 'run_update_mode'


# Make sure we have 'racadm' and 'asu64' installed.
if [[ ! -f /opt/lenovo/toolscenter/asu/asu64 ]]; then
  croak "asu64 is not installed in the expected location"
fi
if [[ ! -f /opt/dell/srvadmin/sbin/racadm-wrapper-idrac7 ]]; then
  croak "racadm-wrapper-idrac7 is not installed in the expected location"
fi


# Process parameters and launch the appropriate function to run tasks.
case $1 in
  -h|--help) usage
    exit 0;;
  -l) [[ $# -eq 2 ]] || croak "incorrect number of parameters, please run with -h for usage"
    NODELIST=$2
    run_list_mode;;
  -u) [[ ! -t 0 ]] && croak "must be run interactively" # stdin is NOT running in a terminal
    [[ $# -eq 3 ]] || croak "incorrect number of parameters, please run with -h for usage"
    NEWPASSWORD=$2
    NODELIST=$3
    run_update_mode;;
  *) [[ $# -eq 1 ]] || croak "incorrect number of parameters, please run with -h for usage"
    NODELIST=$1
    run_standard_mode;;
esac

