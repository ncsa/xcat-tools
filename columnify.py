#!/usr/bin/python
import csv
import tabulate
import sys
import argparse

# Command line Options
parser = argparse.ArgumentParser()
parser.add_argument( '--filter_empty', '-f', action='store_true',
    help='Filter empty columns' )
args = parser.parse_args()


# Process data from stdin
allrows = []
with sys.stdin as fh:
	reader = csv.reader( fh )
	for row in reader:
		allrows.append( row )

# Filter empty cols, if requested
if args.filter_empty:
	cols_with_data=[]
	for ary in allrows[1:]:
		for i,elem in enumerate( ary ):
			if len(elem) > 0:
				cols_with_data.append( i )
	valid_cols = set( sorted( cols_with_data ) )
	cleanrows = []
	for ary in allrows:
		newrow = []
		for i in valid_cols:
			newrow.append( ary[ i ] )
		cleanrows.append( newrow )
	allrows = cleanrows

print( tabulate.tabulate( allrows, headers="firstrow" ) )
