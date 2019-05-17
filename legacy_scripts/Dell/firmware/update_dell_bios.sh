#!/bin/bash

PRG=$( basename $0 )

function croak() {
    echo ERROR: $* >&2
    exit 1
}

function usage() {
    cat <<ENDHERE

$PRG
    Installs firmware updates
Usage:
    $PRG [OPTIONS] {nodenames | noderange}
    where:
        nodenames must be a space separated list of valid nodenames 
        or
        noderange must be a valid noderange expression understood by the 'nodels' command

OPTIONS:
  -h    print help message and exit
  -d    debug mode. script will run without updates.

ENDHERE
}

while [[ $# -gt 0 ]] && [[ $ENDWHILE -eq 0 ]] ; do
    case $1 in
        -h) usage
            exit 0;;
        --) ENDWHILE=1;;
         *) ENDWHILE=1; break;;
    esac
    shift
done

# Verify noderange
if [[ $# -lt 1 ]]; then
    croak "Must specify nodename"
elif [[ $# -eq 1 ]]; then
    nodelist=( $( nodels $1 ) )
else
    nodelist=( $( for a in $*; do nodels $a; done ) )
fi

allnodes=$(IFS=,; echo "${nodelist[*]}")

echo "nodes to be updated: ${nodelist[@]}"

# Select desired firmware directory
echo "Select firmware directory:"
select dn in $(find . -type d -name 'DellFirmware*' -printf "%f\n" | sort -V); do 
    echo You selected ${dn}
    break
done
[[ -z ${dn} ]] && croak "Missing directory"
[[ -d ${dn} ]] || croak "'$dn' is not a directory"
echo OKAY ${dn}

# Select desired firmware to update 
bins=($(ls ${dn} | xargs))
echo "Select firmware package to update:"
select fn in ALL $(find ${dn} -type f -name '*BIN' -printf "%f\n" | sort -V); do 
    echo You selected ${fn}
    if [[ "${fn}" == "ALL" ]]; then
        fn=("${bins[@]}")
    fi
    for i in "${fn[@]}"; do
        [[ -z ${i} ]] && croak "Missing file"
        [[ -e ${dn}/${i} ]] || croak "'${dn}/${i}' is not a file"
        echo OKAY ${i}
    done
break
done

# Create tarball for selected directory
if [ ! -e /root/Dell_firmware/archives/${dn}.tar.gz ]; then
    tar -czvf /root/Dell_firmware/archives/${dn}.tar.gz ${dn}
elif [ -e /root/Dell_firmware/archives/${dn}.tar.gz ]; then
    echo "Archive already exists. skipping."
else
    croak "Problem creating archive"
fi

# Copy and extract tarball to nodes for update
echo "copying archive to ${nodelist[@]}."
xdcp ${allnodes} /root/Dell_firmware/archives/${dn}.tar.gz /root
echo "extracting tarball"
xdsh ${allnodes} tar -zxvf /root/${dn}.tar.gz

# Verify firmware compatibility and install
echo "Installing firmware: "${fn[@]}""
for i in "${fn[@]}"; do
    echo "Installing firmware package ${i} on ${allnodes}"
    xdsh ${allnodes} sh /root/${dn}/${i} -q | xdshbak -c
done

echo "Don't forget to reboot when finished with all updates!"
