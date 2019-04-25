# Require python 3
exitcode=0
import sys
if sys.version_info.major < 3:
    msg = "Requires python version 3; attempted with version '{}'".format( sys.version_info.major )
    exitcode=1
sys.exit( exitcode )
