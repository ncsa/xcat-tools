#!/bin/bash

trap "exit 1" TERM
export XCAT_TOOLS_TOP_PID=$BASHPID

BASE=___INSTALL_DIR___
CONF_BASE=$BASE/conf/reposync.d
LIB=$BASE/libs
PRG=$( basename "$0" )
RHSM_CERT_BASE=/etc/pki/entitlement
TIMESTAMP=$(date +%F-%s)
DEBUG=0

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

usage() {
  cat <<ENDHERE
$PRG
    Sync repos listed under $CONF_BASE/NAME.conf
Usage:
    $PRG [OPTIONS] [file]
    where:
	file is the path to a specific reposync.d/XXX.conf file to source
        (otherwise sync all repos under $BASE/conf/reposync.d/XXX.conf)

    Conf file format:
        A .conf file should define the following variables to source:
        OS=XXX
        ARCH=XXX
        REPO_BASE_DIR=XXX
        REPO_DIR=XXX
        REPOS=(
        REPO1
        REPO2
        )
OPTIONS:
  -h    print help message and exit
  -f    file to source to configure which repos to sync
ENDHERE
}

# IF SYNCING RHSM MANAGED REPOS WE NEED TO MAKE SURE WE ARE POINTING TO THE LATEST entitlement CERTIFICATES
do_update_rhsm_cert_links() {
    [[ $DEBUG -eq 1 ]] && set -x

    if [[ -d "$RHSM_CERT_BASE" ]]
    then
        echo "Updating RHSM entitlement certificate symlinks"
#        KEY=$( find "$RHSM_CERT_BASE" -maxdepth 1 -mindepth 1 -iname '*-key.pem' | head -1 )
#        CERT=$( find "$RHSM_CERT_BASE" -maxdepth 1 -mindepth 1 -iname '*.pem' -not -iname '*-key.pem' | head -1 )
        KEY=$( ls -t $RHSM_CERT_BASE/*-key.pem | head -1 )
        CERT=$( ls -t $RHSM_CERT_BASE/*.pem | grep -v "key.pem" | head -1 )

        if [[ ! -z "$KEY" ]]
        then
            cd "$RHSM_CERT_BASE" && ln -sf "$(basename ${KEY})" key
        else
            echo "Warning: No RHSM entitlement certificate key found"
        fi

        if [[ ! -z "$CERT" ]]
        then
            cd "$RHSM_CERT_BASE" && ln -sf "$(basename ${CERT})" cert
        else
            echo "Warning: No RHSM entitlement public certificate found"
        fi
    else
        echo "Warning: No RHSM entitlement certificates found"
    fi
}

do_reposync() {
    [[ $DEBUG -eq 1 ]] && set -x
    local _cfg_file="$1"
    source "$_cfg_file"

    echo "Syncing repos listed in $_cfg_file"

    local _repo_snap="$REPO_DIR"/"$TIMESTAMP"
    
    if [[ -L "$REPO_DIR/repos" && -d "$REPO_DIR/repos" ]]
    then
        echo "Creating reflink (copy-on-write) snapshot of $REPO_DIR/repos into $_repo_snap..."
        cp -a --reflink=always "$REPO_DIR/repos/" "$_repo_snap"
    
        # Remove the old link
        unlink "$REPO_DIR/repos"
    else
        echo "No previous reposync snapshots found, creating new copy in $_repo_snap"
        mkdir -p "$_repo_snap"
    fi
    
    # Do the reposync, $REPOS defined in the $_cfg_file
    for repo in "${REPOS[@]}"; do
        # Remove the prefix sync- just to keep names cleaner (nothing removed if sync- prefix is absent)
        dst_repo=${repo#"sync-"}
    
        /usr/bin/reposync -p "${_repo_snap}/${dst_repo}" --newest-only --download-metadata --norepopath --repo="${repo}" --exclude="${EXCLUDES}"
    done
    
    # Setup a pointer to the most recent snapshot so we know what dir to copy-on-write next time
    ln -s "$_repo_snap" "$REPO_DIR/repos"

}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0;;
        -f|--file) file="$2"; shift;;
        -d|--debug) DEBUG=1; shift;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

[[ $DEBUG -eq 1 ]] && set -x

do_update_rhsm_cert_links

if [[ -f "$file" ]]; then
    repo_cfg_files=("$file")
else
    repo_cfg_files=($(find $CONF_BASE -name "*.conf"))
fi

for cfg_file in "${repo_cfg_files[@]}"; do
    do_reposync "$cfg_file"
done
