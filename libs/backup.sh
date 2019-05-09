# Use /backup mountpoint if mounted, otherwise use a local destination
# so that /backup remains empty for a future boot.
# When a dir is a mount point, it has a different device number than its parent
MOUNTPOINT='/backup'
MOUNTPOINT_ALTERNATIVE='/backup_local'
if [[ $( stat -fc%t:%T "$MOUNTPOINT" ) != $( stat -fc%t:%T "$MOUNTPOINT/.." ) ]] ; then
    BACKUPDIR="$MOUNTPOINT"
else
    BACKUPDIR="$MOUNTPOINT_ALTERNATIVE"
fi


FULLDATE=`date +%Y%m%d`
BACKUPPATH="$BACKUPDIR/$FULLDATE"
mkdir -p $BACKUPPATH
TIMESTAMP=$( date +%s )
