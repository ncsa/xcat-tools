# ALIASES

## override tabdump to align columns
alias td=___INSTALL_DIR___/admin_scripts/tabdump.sh

## override tabdump to align columns and filter empty cols
alias tdf='___INSTALL_DIR___/admin_scripts/tabdump.sh -f'

## List only tables that have actual data in them
alias tabls=___INSTALL_DIR___/admin_scripts/tabls.sh

## short alias for rebuild_xcat_node
alias rebuild=___INSTALL_DIR___/admin_scripts/rebuild_xcat_node.sh

# FUNCTIONS

## lldef - long listing of all objects of the given type
## like "ls -l" for lsdef
lldef() {
  lsdef -t "$1" | grep "${2:-.}" | awk '{printf("%s,", $1)}' | xargs lsdef -t "$1" -l -o
}

# add xcat-tools to path
[[ ":$PATH:" != *":___INSTALL_DIR___/admin_scripts:"* ]] \
&& PATH="${PATH}:___INSTALL_DIR___/admin_scripts"
for i in Dell Lenovo Puppet; do [[ ":$PATH:" != *":___INSTALL_DIR___/admin_scripts/$i:"* ]] \
&& PATH="${PATH}:___INSTALL_DIR___/admin_scripts/$i"; done
