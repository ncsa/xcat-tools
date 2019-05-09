racadm() {
  # eval defines variables: bmc, bmcusername, bmcpassword
  # as returned by the xCAT table "ipmi"
  eval $( lsdef -t node -o $1 -i bmc,bmcpassword,bmcusername | tail -n+2 )
  shift
  export SSHPASS="$bmcpassword"
  sshpass -e ssh -l $bmcusername $bmc -- racadm "$*" | grep -v 'Default password'
  unset SSHPASS
}
