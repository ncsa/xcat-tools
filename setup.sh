#!/bin/bash

YES=0
NO=1
DEBUG=$NO
VERBOSE=$YES


ensure_epel() {
    local _yumopts=( '-q' )
    [[ $DEBUG -eq $YES ]] && {
        set -x
        _yumopts=()
    }
	yum -y "${_yumopts[@]}" install epel-release
}

install_prereqs() {
    local _yumopts=( '-q' )
    [[ $DEBUG -eq $YES ]] && {
        set -x
        _yumopts=()
    }
	PKGLIST=( bind-utils \
		      iproute \
		      less \
		      lsof \
		      lvm2 \
		      net-tools \
              sshpass \
		      tree \
		      vim \
		      which
	)
    ensure_epel
	yum -y "${_yumopts[@]}" install "${PKGLIST[@]}"
}


set_install_dir() {
    [[ $DEBUG -eq $YES ]] && set -x
    INSTALL_DIR=$HOME/xcat-tools
    [[ -n "$XCAT_TOOLS_INSTALL_DIR" ]] && INSTALL_DIR="$XCAT_TOOLS_INSTALL_DIR"

    [[ -z "$INSTALL_DIR" ]] \
        && croak "Unable to determine install base. Try setting 'XCAT_TOOLS_INSTALL_DIR' env var."

    [[ -d "$INSTALL_DIR" ]] || mkdir -p $INSTALL_DIR

    [[ -d "$INSTALL_DIR" ]] \
    || croak "Unable to find or create script dir: '$INSTALL_DIR'"
}


install_python() {
    [[ $DEBUG -eq $YES ]] && set -x
	YUMPKGLIST=( python36
	)
	yum -y install "${YUMPKGLIST[@]}"
    PYTHON=$(which python3)
}


ensure_python() {
    [[ $DEBUG -eq $YES ]] && set -x
    PYTHON=$(which python3) 2>/dev/null
    [[ -n "$PY3_PATH" ]] && PYTHON=$PY3_PATH
    [[ -z "$PYTHON" ]] && {
        install_python
    }
    [[ -z "$PYTHON" ]] && croak "Unable to find Python3. Try setting 'PY3_PATH' env var."
    "$PYTHON" "$BASE/require_py_v3.py" || croak "Python version too low"
    "$PYTHON" -m ensurepip
#    "$PYTHON" -m pip install -U pip
}


setup_python_venv() {
    [[ $DEBUG -eq $YES ]] && set -x
    venvdir="$INSTALL_DIR/.venv"
    [[ -d "$venvdir" ]] || {
        "$PYTHON" -m venv "$venvdir"
        PIP="$venvdir/bin/pip"
        "$PIP" install --upgrade pip
        "$PIP" install -r "$BASE/requirements.txt"
    }
    V_PYTHON="$venvdir/bin/python"
    [[ -x "$V_PYTHON" ]] || croak "Something went wrong during python venv install."
}


set_shebang_path() {
    [[ $DEBUG -eq $YES ]] && set -x
    newpath="$1"
    shift
    sed -i -e "1 c \#\!$newpath" "$@"
}


mk_bashrcd() {
    [[ $DEBUG -eq $YES ]] && set -x
    local _rcfile _rcdir _rcmsg
    _rcfile="$HOME/.bashrc"
    _rcdir=$HOME/.bashrc.d
    _rcmsg="Include bashrcd"
    [[ -d "$_rcdir" ]] || mkdir -p "$_rcdir"
    [[ -d "$_rcdir" ]] || croak "Cant find or create rcdir: '$_rcdir'"
    # Ensure "include" in bashrc
    grep -q "$_rcmsg" $_rcfile \
    || >>$_rcfile cat <<ENDHERE

# $_rcmsg
[[ -d "$_rcdir" ]] && for f in "$_rcdir"/*.sh ; do source "\$f" ; done
ENDHERE
}


install_scripts() {
    # To prevent "install" from creating a backup when the only change
    # is set_shebang_path() or 'sed ___INSTALL_DIR___', do:
    #   1. Install to a temp dir
    #   2. Make modifications
    #   3. Install from temp dir to tgt dir
    [[ $DEBUG -eq $YES ]] && set -x
    local _srcdir _tgtdir _tmpdir _pattern
    for _src_dn in "${!SCRIPT_INSTALL_MAP[@]}"; do 
        _srcdir="$BASE/$_src_dn"
        _tgtdir=${SCRIPT_INSTALL_MAP[$_src_dn]}
        _tmpdir=$(mktemp -d)

        # (1) install into _tmpdir
        rsync -r "$_srcdir/" "$_tmpdir/"

        # (2a) Update exec path for python scripts
        find "$_tmpdir" -type f -name '*.py' -print \
        | while read ; do
            set_shebang_path "$V_PYTHON" "$REPLY"
        done

        # (2b) Update install path in any scripts that need it
        _pattern=___INSTALL_DIR___
        grep -Rl "$_pattern" "$_tmpdir" \
        | while read; do
            sed -i -e "s?$_pattern?$INSTALL_DIR?" "$REPLY"
        done

        # (3) install from _tmpdir to _tgtdir (ignore tmpl files)
        find "$_tmpdir" -type f ! -iname '*.tmpl' -print \
        | while read; do 
            _dest=$( echo "$REPLY" | sed -e "s?$_tmpdir?$_tgtdir?" )
            _parent=$( dirname "$_dest" )
            mkdir -p "$_parent"
            install -vbC --suffix="$TS" -T "$REPLY" "$_dest"
        done
        find "$_tmpdir" -delete
    done
}


mk_cron_jobs() {
    [[ $DEBUG -eq $YES ]] && set -x
    crondir="${SCRIPT_INSTALL_MAP[cron_scripts]}"
    find "$crondir" -type f -print \
    | while read ; do
        mk_cron "$REPLY" '@daily'
    done
}


populate_script_install_map() {
    # Define where to install files
    # Must do this after INSTALL_DIR is defined
    [[ $DEBUG -eq $YES ]] && set -x
    SCRIPT_INSTALL_MAP=(
         [admin_scripts]="$INSTALL_DIR/admin_scripts" \
              [bashrc.d]="$HOME/.bashrc.d" \
        [client_scripts]="$INSTALL_DIR/client_scripts" \
          [cron_scripts]="$INSTALL_DIR/cron_scripts" \
                [extras]="$INSTALL_DIR/extras" \
                  [libs]="$INSTALL_DIR/libs" \
           [postscripts]="/install/postscripts/custom" \
    )
}


[[ $DEBUG -eq $YES ]] && set -x
BASE=$(readlink -e $( dirname $0 ) )
LIBS=$BASE/libs
TS=$(date +%s)
declare -A SCRIPT_INSTALL_MAP

# Source lib files
imports=( logging cron )
for f in "${imports[@]}"; do
    srcfn="${LIBS}/${f}.sh"
    [[ -f "$srcfn" ]] || {
        echo "Failed to find lib file '$srcfn'"
        exit 1
    }
    source "$srcfn"
done

install_prereqs

set_install_dir
log "Installing into: '$INSTALL_DIR'"

populate_script_install_map #must come after set_install_dir

ensure_python
debug "Got PYTHON: '$PYTHON'"

setup_python_venv

mk_bashrcd

install_scripts

mk_cron_jobs
