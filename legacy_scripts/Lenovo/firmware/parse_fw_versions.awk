BEGIN { 
    FS = ":" 
    out_format = "%-25s %s\n"
}
/^Element Name/ {
    if ( length( ename ) > 0 ) {
        printf( out_format, vers, ename )
    }
    vers = ""
#    printf( "New Element (full line):...\n" )
#    print
    $1=""
    gsub( /^[ \t]+/, "" )
    gsub( /[ \t]+$/, "" )
    ename = $0
}
/^Version/ {
#    print
    $1=""
    gsub( /^[ \t]+/, "" )
    gsub( /[ \t]+$/, "" )
    vers = $0
    if ( length( vers ) < 1 ) {
        vers = "<none>"
    }
}
END {
#    printf( "End of file, printing last found item...\n" )
    printf( out_format, vers, ename )
}
