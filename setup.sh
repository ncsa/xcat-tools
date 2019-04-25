#!/bin/bash

DEBUG=1
VERBOSE=1

die() {
    echo "ERROR: $*" >&2
    exit 2
}


debug() {
    [[ $DEBUG -lt 1 ]] && return
    echo "DEBUG (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


log() {
    [[ $VERBOSE -lt 1 ]] && return
    echo "LOG (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


ensure_epel() {
	yum -y install epel-release
}

install_prereqs() {
	PKGLIST=( bind-utils \
		      iproute \
		      less \
		      lsof \
		      lvm2 \
		      net-tools \
		      tree \
		      vim \
		      which
	)
    ensure_epel
	yum -y install "${PKGLIST[@]}"
}


set_install_dir() {
    [[ $DEBUG -gt 0 ]] && set -x
    INSTALL_DIR=$HOME/scripts
    [[ -n "$ROOT_SCRIPT_DIR" ]] && INSTALL_DIR="$ROOT_SCRIPT_DIR"

    [[ -z "$INSTALL_DIR" ]] \
        && die "Unable to determine install base. Try setting ROOT_SCRIPT_DIR env var."

    [[ -d "$INSTALL_DIR" ]] || mkdir -p $INSTALL_DIR

    [[ -d "$INSTALL_DIR" ]] \
        || die "Unable to find or create script dir: '$INSTALL_DIR'"
}


install_python() {
	YUMPKGLIST=( python36
	)
	yum -y install "${YUMPKGLIST[@]}"
    PYTHON=$(which python3)
}


ensure_python() {
    [[ $DEBUG -gt 0 ]] && set -x
    PYTHON=$(which python3) 2>/dev/null
    [[ -n "$PY3_PATH" ]] && PYTHON=$PY3_PATH
    [[ -z "$PYTHON" ]] && {
        install_python
    }
    [[ -z "$PYTHON" ]] && die "Unable to find Python3. Try setting PY3_PATH env var."
    "$PYTHON" "$BASE/require_py_v3.py" || die "Python version too low"
    "$PYTHON" -m ensurepip
    "$PYTHON" -m pip install -U pip
}


setup_python_venv() {
    [[ $DEBUG -gt 0 ]] && set -x
    venvdir="$INSTALL_DIR/.venv"
    [[ -d "$venvdir" ]] || {
        "$PYTHON" -m venv "$venvdir"
        PIP="$venvdir/bin/pip"
        "$PIP" install --upgrade pip
        "$PIP" install -r "$BASE/requirements.txt"
    }
    V_PYTHON="$venvdir/bin/python"
    [[ -x "$V_PYTHON" ]] || die "Something went wrong during python venv install."
}


set_shebang_path() {
    [[ $DEBUG -gt 0 ]] && set -x
    newpath="$1"
    shift
    sed -i -e "1 c \#\!$newpath" "$@"
}


check_or_create_bashrcd() {
    [[ $DEBUG -gt 0 ]] && set -x
    rcdir=$HOME/.bashrc.d
    qs=https://raw.githubusercontent.com/andylytical/bashrc/master/quickstart.sh
    [[ -d "$rcdir" ]] || {
        log "Creating: '$rcdir'"
        curl "$qs" | /bin/bash
    }
    [[ -d "$rcdir" ]] || die "Cant find or create rcdir: '$rcdir'"
}


install_scripts() {
    [[ $DEBUG -gt 0 ]] && set -x
    find "$BASE/scripts/" -type f -print \
    | while read ; do
        fn=$( basename "$REPLY" )
        install -vbC --suffix="$TS" -t "$INSTALL_DIR" $REPLY
    done
    # fix exec path for python scripts
    find "$INSTALL_DIR" -maxdepth 1 -type f -name '*.py' -print \
    | while read ; do
        set_shebang_path "$V_PYTHON" "$REPLY"
    done
}


install_bashrcd() {
    [[ $DEBUG -gt 0 ]] && set -x
    tgtdir="$HOME/.bashrc.d"
    find "$BASE/bashrc.d/" -type f -print \
    | while read; do
        fn=$( basename "$REPLY" )
        install -vbC --suffix="$TS" -m '0644' -t "$tgtdir" $REPLY
        sed -i -e "s?___INSTALL_DIR___?$INSTALL_DIR?" "$tgtdir/$fn"
    done
}


[[ $DEBUG -gt 0 ]] && set -x
BASE=$(readlink -e $( dirname $0 ) )
debug "Got BASE: '$BASE'"
TS=$(date +%s)

install_prereqs

set_install_dir
log "Installing into: '$INSTALL_DIR'"

ensure_python
debug "Got PYTHON: '$PYTHON'"

check_or_create_bashrcd

setup_python_venv

install_scripts
find "$INSTALL_DIR" -maxdepth 1 -type f -name '*.py' -newer "$BASE" \
| while read ; do
    log "Installed: '$REPLY'"
done

install_bashrcd
find "$HOME/.bashrc.d" -newer "$BASE" \
| while read ; do
    log "Installed: '$REPLY'"
done
