###
# This custom script borrowed heavily from /install/autoinst/<NODENAME>
# -ALoftus (13 Apr 2018)
###

# Partitions will be the smaller of percent and maxsize
# max_* should be specified in MB
pct_boot=1
max_boot=512
pct_swap=1
max_swap=2048
pct_root=10
max_root=100000
pct_var=5
max_var=40000
pct_tmp=5
max_tmp=20000

# xcat expects kickstart sytax in this file
partfile=/tmp/partitionfile

# get install disk from xcat
install_disk_file="/tmp/xcat.install_disk"
instdisk=/dev/sda #default for debugging
if [ -e "$install_disk_file" ]; then
    instdisk=`cat $install_disk_file`
fi

# get disk raw size
instdisk_raw_bytes=$(blockdev --getsize64 $instdisk)

# Custom function
min() {
    # Print smaller of two numbers
    local a="$1"
    local b="$2"
    [[ "$a" -lt "$b" ]] && echo "$a" || echo "$b"
}

# Custom function
x_pct_of_y() {
    # Print x percent of y (integer math)
    local x="$1"
    local y="$2"
    let "z=($y*$x)/100"
    echo "$z"
}

# Custom function
partcalc() {
    # Print the smaller of:
    #   percent of raw disk size
    #   maxsize
    local pct="$1"
    local max_mb="$2"
    local max_bytes
    let "max_bytes=$max_mb*1048576"
    local sz_bytes=$( min "$max_bytes" $( x_pct_of_y "$pct" "$instdisk_raw_bytes" ) )
    let "sz_mb=$sz_bytes/1048576"
    echo "$sz_mb"
}

# Partitions should be the smaller of percent and maxsize
sz_boot=$( partcalc "$pct_boot" "$max_boot" )
sz_swap=$( partcalc "$pct_swap" "$max_swap" )
sz_root=$( partcalc "$pct_root" "$max_root" )
sz_var=$(  partcalc "$pct_var"  "$max_var" )
sz_tmp=$(  partcalc "$pct_tmp"  "$max_tmp" )
#echo "boot:$sz_boot"
#echo "swap:$sz_swap"
#echo "root:$sz_root"
#echo "var:$sz_var"
#echo "tmp:$sz_tmp"
#exit

# Clobber existing file as a safety precaution
: >$partfile

modprobe ext4 >& /dev/null
modprobe ext4dev >& /dev/null
if grep ext4dev /proc/filesystems > /dev/null; then
	FSTYPE=ext3
elif grep ext4 /proc/filesystems > /dev/null; then
	FSTYPE=ext4
else
	FSTYPE=ext3
fi
BOOTFSTYPE=ext3
EFIFSTYPE=vfat

if uname -r|grep -q '^3.*el7'; then
    BOOTFSTYPE=xfs
    FSTYPE=xfs
    EFIFSTYPE=efi
fi

echo "ignoredisk --only-use=$instdisk" >> $partfile
if [ `uname -m` = "ppc64" -o `uname -m` = "ppc64le" ]; then
	echo 'part None --fstype "PPC PReP Boot" --ondisk '$instdisk' --size 8' >> $partfile
fi
if [ -d /sys/firmware/efi ]; then
    echo 'part /boot/efi --size 50 --ondisk '$instdisk' --fstype '$EFIFSTYPE >> $partfile
fi

#TODO: ondisk detection, /dev/disk/by-id/edd-int13_dev80 for legacy maybe, and no idea about efi.  at least maybe blacklist SAN if mptsas/mpt2sas/megaraid_sas seen...
(
echo "part /boot --size $sz_boot --fstype $BOOTFSTYPE --ondisk $instdisk"
echo "part swap --size $sz_swap --fstype swap --ondisk $instdisk"
echo "part pv.system --size 1 --grow --ondisk $instdisk"
echo "volgroup VGsystem pv.system"
echo "logvol /    --vgname=VGsystem --name=LVroot --size $sz_root --fstype $FSTYPE"
echo "logvol /tmp --vgname=VGsystem --name=LVtmp  --size $sz_tmp  --fstype $FSTYPE"
echo "logvol /var --vgname=VGsystem --name=LVvar  --size $sz_var  --fstype $FSTYPE"
) >> $partfile

#specify "bootloader" configuration in "/tmp/partitionfile" if there is no user customized partition file
BOOTLOADER="bootloader "

#Specifies which drive the boot loader should be written to
#and therefore which drive the computer will boot from.
[ -n "$instdisk" ] && BOOTLOADER=$BOOTLOADER" --boot-drive=$(basename $instdisk)"

echo "$BOOTLOADER" >> $partfile
