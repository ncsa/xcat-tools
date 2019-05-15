#!/bin/bash

BASE=___INSTALL_DIR___
LIB=$BASE/libs
TABDUMP=/opt/xcat/sbin/tabdump

[[ $# -lt 1 ]] && { $TABDUMP; exit 0
}

tablename="${!#}"
params="${@:1:$(($#-1))}"
$TABDUMP $tablename | $BASE/admins_scripts/columnify.py $params
