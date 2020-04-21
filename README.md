# xcat-tools
Useful tools for xCAT

# Installation / Update

### Quick Install (into $HOME/xcat-tools)
```bash
export QS_REPO=https://github.com/ncsa/xcat-tools
curl https://raw.githubusercontent.com/andylytical/quickstart/master/quickstart.sh | bash
```

### Customizable install options
- Pull from a branch (not master)
  ```bash
  export QS_GIT_BRANCH=branch_name`
  ```
- Specify a custom install location (not $HOME/xcat-tools)
  ```bash
  export XCAT_TOOLS_INSTALL_DIR=/custom/install/path
  ```

:information_source: NOTE: Install also touches `$HOME/.bashrc` and `$HOME/.bashrc.d`, regardless of XCAT_TOOLS_INSTALL_DIR


# Usage
## Postscripts
Postscripts are installed into `/install/postscripts/custom`.

Add these to the xCAT postscripts table using the path `custom/<SCRIPTNAME>` ... 
EXCEPT for those noted below

EXCEPTION:
For postscripts that have the same name as an xCAT-provided postscript, the original (file in 
`/install/postscripts`) will be moved aside (renamed with a timestamp suffix) and
a symlink created that points to the custom copy (file in `/install/postscripts/custom`.)
When specifying these scripts in the postscripts table, do NOT include the `custom/` path.
Specify them as normal, using just the scriptname itself. (The original scripts expect
to be found and run from `/install/postscripts` and expect to source and include other
scripts from that directory. The symlink will allow xcat to find the script in the expected
location.)

# Admin Scripts
## tabdump / td
Align tabdump output by column
```
# td mac
#node            interface    mac                comments    disable
---------------  -----------  -----------------  ----------  ---------
monitor01                     08:94:ef:10:49:54
backup01                      08:94:ef:16:08:97
verify-worker01               a0:36:9f:9b:2d:b2
```
Filter empty columns
```
# td -f mac
#node            mac
---------------  -----------------
monitor01        08:94:ef:10:49:54
backup01         08:94:ef:16:08:97
verify-worker01  a0:36:9f:9b:2d:b2
```

## tabls
List only tables that have valid data
```
# ./tabls
auditlog
bootparams
chain
discoverydata
hosts
hwinv
ipmi
linuximage
mac
networks
nics
nodegroup
nodehm
nodelist
noderes
nodetype
osimage
passwd
policy
postscripts
routes
site
switch
switches
vpd
```

## hwinfo
Get hardware details for specific nodes.
```
[root@adm01 scripts]# ./hwinfo monitor01
HOSTS -------------------------------------------------------------------------
monitor01
-------------------------------------------------------------------------------
Manufacturer ID: Lenovo (19046)
System Description: System x3650 M5
DIMM 1 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 12 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 13 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 16 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 21 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 24 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 4 : 16GB PC4-17000 (2132 MT/s) RDIMM
DIMM 9 : 16GB PC4-17000 (2132 MT/s) RDIMM
CPU 1 Product Version: Intel(R) Xeon(R) CPU E5-2650 v3 @ 2.30GHz
CPU 2 Product Version: Intel(R) Xeon(R) CPU E5-2650 v3 @ 2.30GHz
disk  998999326720 ServeRAID M1215
disk 6001175126016 ST6000NM0034   X
disk 6001175126016 ST6000NM0034   X

```


## rebuild_xcat_node
Get current provmethod for a node and re-assign it,

then set the node to PXE boot (netboot) once at next boot,

then reboot the node, thus forcing a reinstall.
```
Usage:
    rebuild_xcat_node [OPTIONS] {nodenames | noderange}
    where:
        nodenames must be a space separated list of valid nodenames
        or
        noderange must be a valid noderange expression understood by the 'nodels' command

OPTIONS:
  -h --help  print help message and exit
  -v         show what is happening
  -n         Dryrun, show what would have been done, but don't actually do it
  -p S       Pause for S seconds between each node rebuild (default: 5)
MUTUALLY EXCLUSIVE OPTIONS:
  --osimage OSIMAGE  Set a different osimage
  --shell            Boot to xCAT genesis shell
  --runimage URL     Boot xCAT genesis kernel, download the tgz, unpack and run runme.sh
  --skip-nodeset     Do NOT run nodeset, do only 1.set netboot and 2.power cycle

```
