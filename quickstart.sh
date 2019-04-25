#!/bin/bash

tmpdir=$(mktemp -d)
git clone https://github.com/ncsa/xcat-tools.git $tmpdir
$tmpdir/setup.sh
rm -rf $tmpdir
