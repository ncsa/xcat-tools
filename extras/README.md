# xcat-tools/extras

### mk_root_100.sh
Custom partitioning scheme.

Install into an osimage:
```
mkdir -p /install/custom
cp <path_to>/xcat-tools/extras/mk_root_100.sh /install/custom/
chdef -t osimage -o <OSIMAGE_NAME> partitionfile=s:/install/custom/mk_root_100.sh
```

### sanitize.sh
Clean install area, for debugging setup.sh
