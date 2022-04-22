#!/bin/bash

YES=0
NO=1
#DEBUG=$NO
DEBUG=$YES
VERBOSE=$YES

croak() {
  echo "FATAL ERROR: $*" 1>&2
  exit 99
}


set_proxy() {
  PROXY=
  local _proxy="$https_proxy"
  # try environment https
  [[ -z "$_proxy" ]] && \
    _proxy="$http_proxy"
  # try environment http
  [[ -z "$_proxy" ]] && \
    _proxy="$https_proxy"
  # try git
  [[ -z "$_proxy" ]] && which git &>/dev/null && \
    _proxy="$( git config --global --get http.proxy )"
  # try curlrc
  [[ -z "$_proxy" ]] && [[ -r ~/.curlrc ]] && \
    _proxy="$( awk '/^proxy/{print $NF}' ~/.curlrc )"
  # If found, export environment var
  # [[ -n "$_proxy" ]] && export https_proxy="$_proxy"
  [[ -n "$_proxy" ]] && PROXY="$_proxy"
}


get_os_name() {
  if [[ -r /etc/os-release ]] ; then
    grep '^ID=' /etc/os-release | cut -d= -f2 | tr -cd '[A-Za-z0-9]'
  fi
}


ensure_epel() {
  local _yumopts=( '-q' )
  [[ $DEBUG -eq $YES ]] && {
    set -x
    _yumopts=()
  }
  local _osname=$( get_os_name )
  local _pkgname
  case "$_osname" in
    rhel)
      _pkgname='https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'
      ;;
    centos)
      _pkgname='epel-release'
      ;;
    *)
      croak "Unsupported OS => '$_osname'"
      ;;
  esac
	yum -y "${_yumopts[@]}" install "$_pkgname"
}


install_prereqs() {
  local _yumopts=( '-q' )
  [[ $DEBUG -eq $YES ]] && {
    set -x
    _yumopts=()
  }
	PKGLIST=( \
    bind-utils \
    iproute \
    less \
    lsof \
    lvm2 \
    net-tools \
    rsync \
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
	YUMPKGLIST=( \
    python3
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
}


setup_python_venv() {
  [[ $DEBUG -eq $YES ]] && set -x
  venvdir="$INSTALL_DIR/.venv"
  [[ -d "$venvdir" ]] || {
    "$PYTHON" -m venv "$venvdir"
    PIP="$venvdir/bin/pip"
    PIP_PROXY="${PROXY:+--proxy $PROXY}"
    "$PIP" $PIP_PROXY install --upgrade pip
    "$PIP" $PIP_PROXY install -r "$BASE/requirements.txt"
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
  grep -q "$_rcmsg" $_rcfile || >>$_rcfile cat <<ENDHERE

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

    # (3) install from _tmpdir to _tgtdir
    find "$_tmpdir" -type f -print \
    | while read; do 
      _dest=$( echo "$REPLY" | sed -e "s?$_tmpdir?$_tgtdir?" )
      _parent=$( dirname "$_dest" )
      mkdir -p "$_parent"
      install_allowed "$_dest" \
      && install -vbC --suffix="$TS" -T "$REPLY" "$_dest"
    done
    find "$_tmpdir" -delete
  done
}


mk_cron_jobs() {
  [[ $DEBUG -eq $YES ]] && set -x
  local _crondir="${SCRIPT_INSTALL_MAP[cron_scripts]}"
  find "$_crondir" -type f -name '*.sh' -print \
  | while read ; do
    mk_cron "$REPLY" '@daily'
  done
}


symlink_postscripts() {
  # If a custom postscript has the same name as an xcat-provided postscript,
  # then 
  # 1. rename the xcat original and
  # 2. create a symlink to the custom script
  [[ $DEBUG -eq $YES ]] && set -x
  local _psdir=/install/postscripts
  local _custom_psdir="${SCRIPT_INSTALL_MAP[postscripts]}"
  local _custom_ps_path _fn _orig_path
  find "$_custom_psdir" -type f -print \
  | while read; do
    _custom_ps_path="$REPLY"
    _fn=$(basename "$_custom_ps_path")
    _orig_path="$_psdir/$_fn"
    [[ -f "$_orig_path" && ! -L "$_orig_path" ]] && {
      mv "$_orig_path" "${_orig_path}.$TS"
      ln -s "$_custom_ps_path" "$_orig_path"
    }
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
	      [conf]="$INSTALL_DIR/conf" \
       [postscripts]="/install/postscripts/custom" \
  )
}


install_allowed() {
  # Determine if install / update is allowed
  [[ $DEBUG -eq $YES ]] && set -x
  # List of files that should never be updated
  local _ignore_update_files=(
    backup-node_configs.sources \
  )
  local _tgt_file="$1"
  local _tgt_fn=$( basename "$1" )
  local _rv=0
  [[ -z "$_tgt_file" ]] && croak "got empty target filename"
  [[ -z "$_tgt_fn" ]] && croak "got empty basenae for filename"
  if [[ -e "_tgt_file" ]] ; then
    [[ ${_ignore_update_files["$_tgt_fn"]}+abc ]] && _rv=1
  fi
  return $_rv
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

# Set proxy
set_proxy

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

symlink_postscripts
