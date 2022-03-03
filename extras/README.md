# xcat-tools/extras

### parts_by_percent.sh
Custom partitioning scheme.

Install into an osimage:
```
mkdir -p /install/custom
cp <path_to>/xcat-tools/extras/parts_by_percent.sh /install/custom/
chdef -t osimage -o <OSIMAGE_NAME> partitionfile=s:/install/custom/parts_by_percent.sh
```

### sanitize.sh
Clean install area, for debugging setup.sh

### xcat_install.sh
curl -O
https://raw.githubusercontent.com/ncsa/xcat-tools/new_install_script/extras/xcat_install.sh
bash xcat_install.sh

### xcat_setup.sh
/root/xcat-tools/extras/xcat_setup.sh

### wipealldisks
A runcmd script to wipe all disks.
`/opt/xcat/share/xcat/netboot/genesis/x86_64/fs/bin/wipealldisks`
`mknb x86_64`
`rinstall NODE runcmd=wipealldisks`
