# xcat-tools
Useful tools for xCAT

# Installation
1. `mkdir working; cd working`
1. `git clone https://github.com/ncsa/xcat-tools.git`
1. `cp bashrc_aliases /root/.xcat_aliases`
1. `echo . ~/.xcat_aliases >> /root/.bashrc`
1. `mkdir /root/scripts`
1. `cp tab* *.py rebuild* hw* /root/scripts/`
1. `chmod +x /root/scripts/*`
 
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

## get_lenovo_mac
Uses `nodels` and `rinv` to get first mac address and apply it to the node
definition.  Works only if `rinv` can get mac addresses from the node.
