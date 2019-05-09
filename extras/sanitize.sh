#!/bin/bash

# Clear dirs
dirs=( $HOME/xcat-tools $HOME/.bashrc.d )
for d in "${dirs[@]}" ; do
    find $d -delete
done

# Clear crontab
</dev/null crontab -

# Reset default bashrc
cp $HOME/.bashrc.orig $HOME/.bashrc
