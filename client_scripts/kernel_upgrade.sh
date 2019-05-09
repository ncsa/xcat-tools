#!/bin/bash

PUPPET=/opt/puppetlabs/bin/puppet

# Always enable these repos
ENABLED_REPOS=( centosplus \
              extras \
              updates \
              base \
              epel \
            )

FIRSTRUN_ENABLED_REPOS=( "${ENABLED_REPOS[@]}" )
FIRSTRUN_DISABLED_REPOS=( )
FIRSTRUN_DISABLED_PACKAGES=( )

SECONDRUN_ENABLED_REPOS=( "${ENABLED_REPOS[@]}" )
SECONDRUN_DISABLED_REPOS=( )
SECONDRUN_DISABLED_PACKAGES=( )

set -x
# KERNEL UPGRADE SCRIPT
#
# 1. FORCE YUM UPDATE OF KERNEL
# 2. REBUILD VMWARE KERNEL MODULES (IF VM)
# 3. REBOOT, ALERTING LOGGED IN USERS FIRST

croak() {
    echo "ERROR: $*"
    exit 99
}


get_pup_run_state() {
    $PUPPET resource service puppet \
    | awk '/ensure/ {gsub(/[^a-zA-Z]/,"",$NF);print $NF}'
}


kernel_was_upgraded() {
    local yum_kernel rpm_kernel cur_kernel
    yum_kernel=$( 
        awk '/Installed: kernel-[0-9]/ {print $NF}' /var/log/yum.log \
        | tail -1 )
    rpm_kernel=$( 
        rpm -qa --qf '%{INSTALLTIME} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
        | egrep 'kernel-[0-9]' \
        | sort -n \
        | tail -1 \
        | awk '{print $NF}' )
    cur_kernel=kernel-$( uname -r )
    echo "Yum log kernel: $yum_kernel"
    echo "Newest RPM ker: $rpm_kernel"
    echo "Current kernel: $cur_kernel"
    [[ -z $yum_kernel ]] && yum_kernel=$cur_kernel #set default if empty
    [[ -z $rpm_kernel ]] && rpm_kernel=$cur_kernel #set default if empty
    rc=1
    [[ "$cur_kernel" != "$yum_kernel"  ||  "$cur_kernel" != "$rpm_kernel" ]]
}


REBOOT_REQUIRED=0
FORCE_REBOOT=0
ENDWHILE=0
while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -r | --reboot)
            FORCE_REBOOT=1
            ;;
        --) ENDWHILE=1
            ;;
         *) ENDWHILE=1
            break
            ;;
    esac
    shift
done


# DISABLE PUPPET AGENT WHILE UPGRADING
OLD_PUP_STATE=$( get_pup_run_state )
$PUPPET resource service puppet ensure=stopped

# SHUTDOWN GPFS WHILE UPGRADING
/root/gpfs_unmount.sh || croak "unable to shutdown gpfs"

# UPGRADE KERNEL
tmpfn=$( mktemp )
echo "LOGFILE: $tmpfn"
echo "CHECKING FOR KERNEL UPGRADES..."

/usr/bin/yum ${FIRSTRUN_ENABLED_REPOS[@]/#/--enablerepo=} clean all
rm -rf /var/cache/yum

# DO WE HAVE A KUBERNETES REPO?
grep -q '\[kubernetes\]' /etc/yum.repos.d/* && { 
    FIRSTRUN_DISABLED_REPOS+=( 'kubernetes' )
    SECONDRUN_DISABLED_REPOS+=( 'kubernetes' )
}

# FIRST RUN
/usr/bin/yum \
${FIRSTRUN_ENABLED_REPOS[@]/#/--enablerepo=} \
${FIRSTRUN_DISABLED_REPOS[@]/#/--disablerepo=} \
${FIRSTRUN_DISABLED_PACKAGES[@]/#/--exclude=} \
-y \
upgrade \
&>$tmpfn

# SECOND RUN
/usr/bin/yum \
${SECONDRUN_ENABLED_REPOS[@]/#/--enablerepo=} \
${SECONDRUN_DISABLED_REPOS[@]/#/--disablerepo=} \
${SECONDRUN_DISABLED_PACKAGES[@]/#/--exclude=} \
-y \
upgrade \
&>>$tmpfn

# CHECK IF KERNEL UPGRADED
if kernel_was_upgraded ; then
    echo "kernel updated to $yum_kernel via yum."
    REBOOT_REQUIRED=1
else
    echo "Kernel was not updated."
fi

# Re-set puppet service to previous state
$PUPPET resource service puppet ensure=$OLD_PUP_STATE

# REBOOT
if [[ $FORCE_REBOOT -eq 1 -o $REBOOT_REQUIRED -eq 1 ]] ; then
    echo "REBOOTING SERVER..."
    /sbin/shutdown -r now
fi
