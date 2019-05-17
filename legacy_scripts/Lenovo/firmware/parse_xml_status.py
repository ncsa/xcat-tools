#!/bin/python

import xmltodict
import argparse
import pprint

parser = argparse.ArgumentParser( 
    description='Process Lenovo OneCli update status xml file' )
parser.add_argument( 'filenames', nargs='+' )
args = parser.parse_args()

for f in args.filenames:
    with open( f ) as fh:
        doc = xmltodict.parse( fh.read() )
    #pprint.pprint( doc )
    pkglist = doc['FLASH']['CONTENT']['PACKAGES']['PACKAGE']
#    pprint.pprint( pkglist )
    for pkg in pkglist:
#        pprint.pprint( pkg )
        component = pkg['COMPONENT']
        reboot = pkg['REBOOT']
#        status = pkg['STATUS']
        rcode = pkg['RCODE']
#        result = pkg['RESULT']
        print( 'Component:{} Rcode:{} Reboot:{}'.format( component, rcode, reboot ) )
