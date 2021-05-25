# Custom xCAT Postscripts
Installed into `/install/postscripts/custom`

NOTE: The following postscripts are normally provided by xCAT but are modified
here by xcat-tools and thus, effectively overwritten (actually moved aside and
symlinked). A manual effort must be made to keep these modifications
up-to-date.
* confignetwork
* configeth

# Keeping things up to date
### Update confignetwork
1. `curl -O https://github.com/xcat2/xcat-core/blob/master/xCAT/postscripts/confignetwork`
1. Fix the `grep` in the `get_installnic` funtion
```bash
function get_installnic {

    tmp_installnic="mac"
    [ $INSTALLNIC ] && tmp_installnic=$INSTALLNIC

    instnic=''
    if [ "$tmp_installnic" = "mac" ];then
        if [ -n "$MACADDRESS" ]; then
            instnic=`ip -o link | grep -i "$MACADDRESS" | awk '{print $2;}' | sed s/://`
        else
            errorcode=1
        fi
    ### NCSA - FIX FOR DELL NODES WITH INTERFACE NAMES LIKE p1p2
    elif [ `echo $tmp_installnic | grep -E "(p[0-9]p|em|en|eth)[0-9a-zA-Z]+"` ];then
        instnic=$tmp_installnic
    else
            errorcode=1
    fi
    echo $instnic
}
```
### Update configeth
1. `curl -O https://github.com/xcat2/xcat-core/blob/master/xCAT/postscripts/configeth`
1. Set `reboot_nic_bool=1`
```bash
#########################################################################
# ifdown/ifup will not be executed in diskful provision postscripts stage
#########################################################################
if [ -z "$UPDATENODE" ] || [ $UPDATENODE -ne 1 ] ; then
    if [ "$NODESETSTATE" = "install" ] && ! grep "REBOOT=TRUE" /opt/xcat/xcatinfo >/dev/null 2>&1; then
        reboot_nic_bool=0
    fi
fi
### NCSA - always bring up the interface so yum can install latest updates before node reboots
reboot_nic_bool=1
```
