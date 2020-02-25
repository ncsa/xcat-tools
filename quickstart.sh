#!/bin/bash

branch=${XCAT_TOOLS_GIT_BRANCH:-master}
tmpdir=$(mktemp -d)
git clone \
    --single-branch \
    --branch "$branch" \
    https://github.com/ncsa/xcat-tools.git \
    $tmpdir
$tmpdir/setup.sh
rm -rf $tmpdir
