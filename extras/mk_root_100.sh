###
# This custom script borrowed heavily from /install/autoinst/<NODENAME>
###

# PCT must be between 1 & 100
# MIN and MAX are sizes in MB
declare -A BOOT SWAP VAR TMP ROOT VARLIB
BOOT=(   [MIN]=512  [PCT]=1  [MAX]=1024 )
SWAP=(   [MIN]=512  [PCT]=1  [MAX]=2048 )
VAR=(    [MIN]=3000 [PCT]=5  [MAX]=40000 )
TMP=(    [MIN]=1500 [PCT]=5  [MAX]=20000 )
ROOT=(   [MIN]=6000 [PCT]=10 [MAX]=100000 )
VARLIB=( [MIN]=6000 [PCT]=10 [MAX]=100000 )

# xcat expects kickstart syntax in this file
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
max() {
    # Print larger of two numbers
    local a="$1"
    local b="$2"
    [[ "$a" -gt "$b" ]] && echo "$a" || echo "$b"
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
    # Calculate the partition size using pct constrained the bounds of min & max
    local _min_mb="$1"
    local _pct="$2"
    local _max_mb="$3"
    local _min_bytes _pct_bytes _max_bytes _sz_bytes _sz_bm
    let "_min_bytes=$_min_mb*1048576"
    let "_max_bytes=$_max_mb*1048576"
    # calculate num bytes as percent of disk
    _pct_bytes=$( x_pct_of_y "$_pct" "$instdisk_raw_bytes" )
    # enforce maximum bound
    _sz_bytes=$( min "$_max_bytes" "$_pct_bytes" )
    # enforce minimum bound
    _sz_bytes=$( max "$_min_bytes" "$_sz_bytes" )
    let "_sz_mb=$_sz_bytes/1048576"
    echo "$_sz_mb"
}

# Partitions should be the smaller of percent and maxsize
#echo BOOT
sz_boot=$( partcalc "${BOOT[MIN]}" "${BOOT[PCT]}" "${BOOT[MAX]}" )
#echo "boot:$sz_boot"
#exit
#echo SWAP
sz_swap=$( partcalc "${SWAP[MIN]}" "${SWAP[PCT]}" "${SWAP[MAX]}" )
#echo "swap:$sz_swap"
#exit
#echo VAR
sz_var=$(  partcalc "${VAR[MIN]}" "${VAR[PCT]}" "${VAR[MAX]}" )
#echo TMP
sz_tmp=$(  partcalc "${TMP[MIN]}" "${TMP[PCT]}" "${TMP[MAX]}" )
#echo ROOT
sz_root=$( partcalc "${ROOT[MIN]}" "${ROOT[PCT]}" "${ROOT[MAX]}" )
#echo VARLIB
sz_varlib=$( partcalc "${VARLIB[MIN]}" "${VARLIB[PCT]}" "${VARLIB[MAX]}" )
#echo "boot:$sz_boot"
#echo "swap:$sz_swap"
#echo "var:$sz_var"
#echo "tmp:$sz_tmp"
#echo "root:$sz_root"
#echo "varlib:$sz_varlib"
#exit

# Try to smartly determine filesystem type
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

# Clobber existing file as a safety precaution
: >$partfile

# Create new partfile
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
echo "logvol /var/lib --vgname=VGsystem --name=LVvarlib  --size $sz_varlib  --fstype $FSTYPE"
) >> $partfile

#specify "bootloader" configuration in "/tmp/partitionfile" if there is no user customized partition file
BOOTLOADER="bootloader "

#Specifies which drive the boot loader should be written to
#and therefore which drive the computer will boot from.
[ -n "$instdisk" ] && BOOTLOADER=$BOOTLOADER" --boot-drive=$(basename $instdisk)"

echo "$BOOTLOADER" >> $partfile
