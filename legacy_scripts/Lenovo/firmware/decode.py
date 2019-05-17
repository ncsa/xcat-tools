import fileinput
import re
import pprint

re_code = re.compile( '-\[(.*)\]-' )

data = {}

keys = [ 'serial',
         'machine_type',
         'bios_version_code',
         'bios_version_number',
         'bios_fw_version',
       ]

nodename = ''
for line in fileinput.input():
    parts = line.split()
    nodename = parts[0][0:-1]
    #initialize new nodename
    if nodename not in data:
        data[nodename] = {}
#    #identify dmi decode output section
#    if 'DMI type 0' in line:
#        section = 'BIOS'
#        continue
#    elif 'DMI type 1' in line:
#        section = 'System'
#        continue
    # parse BIOS details
    elif 'Version: -[' in line:
        match = re_code.match( parts[-1] )
        if match:
            data[nodename]['bios_version_code'] = match.group(1)
    elif 'BIOS Revision: ' in line:
        data[nodename]['bios_version_number'] = parts[-1]
    elif 'Firmware Revision: ' in line:
        data[nodename]['bios_fw_version'] = parts[-1]
    # parse System details
    elif 'Product Name: ' in line:
        match = re_code.match( parts[-1] )
        if match:
            data[nodename]['machine_type'] = match.group(1)
    elif 'Serial Number: ' in line:
        data[nodename]['serial'] = parts[-1]

print( ','.join( ['nodename'] + keys ) )
for node,nodedata in data.iteritems():
    parts = [ node ]
    for k in keys:
        parts.append( nodedata[k] )
    print( ','.join( parts ) )
