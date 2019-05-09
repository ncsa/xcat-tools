# override tabdump to align columns
alias td=___INSTALL_DIR___/admin_scripts/tabdump.sh

# override tabdump to align columns and filter empty cols
alias tdf='___INSTALL_DIR___/admin_scripts/tabdump.sh -f'

# List only tables that have actual data in them
alias tabls=___INSTALL_DIR___/admin_scripts/tabls.sh

# short alias for rebuild_xcat_node
alias rebuild=___INSTALL_DIR___/admin_scripts/rebuild_xcat_node.sh

# add xcat-tools to path
[[ ":$PATH:" != *":___INSTALL_DIR___/admin_scripts:"* ]] \
&& PATH="${PATH}:___INSTALL_DIR___/admin_scripts"
