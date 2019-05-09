# xcat-tools
Useful tools for xCAT

# Installation
1. `curl https://raw.githubusercontent.com/ncsa/xcat-tools/master/quickstart.sh | bash`

|||
| --- | --- |
| :information_source: | Default install location is `$HOME/xcat-tools` |
|| For custom install location, use: `export XCAT_TOOLS_INSTALL_DIR=/custom/install/path` |
|| Install also touches `$HOME/.bashrc` and `$HOME/.bashrc.d` |

# Usage
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
