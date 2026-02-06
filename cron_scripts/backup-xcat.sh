#!/bin/bash

DEBUG=1

BASE=___INSTALL_DIR___
LIB=$BASE/libs
DBDUMP=/opt/xcat/sbin/dumpxCATdb
NUM_OLD_BKUPS_TO_KEEP=200

# Import libs
imports=( logging backup pathmunge )
for f in "${imports[@]}"; do
    srcfn="${LIB}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done

[[ $DEBUG -eq 1 ]] && set -x

# Ensure xcat scripts are in PATH
pathmunge /opt/xcat/sbin
export PATH

# Ensure empty snapdir
SNAPDIR="$BACKUPPATH/XCATSNAPDIR"
[[ -d "$SNAPDIR" ]] && find "$SNAPDIR" -delete
mkdir -p "$SNAPDIR"
[[ -d "$SNAPDIR" ]] || {
    echo "Failed creating SNAPDIR '$SNAPDIR'"
    exit 1
}

# Backup xCAT databases
$DBDUMP -p "$SNAPDIR"

# Add custom data to xcat backup ?
#pushd "$SNAPDIR"
#mkdir -p install
#cp -a /install/files install/
#cp -a /install/custom install/
#popd

# Compress the backup
hn=$( hostname | cut -d '.' -f 1 )
bkup_fn=$BACKUPPATH/${TIMESTAMP}_xcatbkup_${hn}
pushd "$SNAPDIR"
tar -zcf "${bkup_fn}.tgz" .
popd
find "$SNAPDIR" -delete

# Clean old backups
find $BACKUPDIR  -mindepth 1 -maxdepth 1 -type d \
| sort -r \
| tail -n +$NUM_OLD_BKUPS_TO_KEEP \
| xargs -r rm -rf

# Remove empty dirs
find $BACKUPDIR -type d -empty -delete
