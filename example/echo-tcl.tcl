#! /usr/bin/env tclsh
#
#  echo-tcl --
#
# 	Produce a page containing all FastCGI inputs
#
# Copyright (c) 1996 Open Market, Inc.
#
# See the file "LICENSE.TERMS" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#  $Id: echo-tcl,v 1.2 1996/10/30 14:38:01 mbrown Exp $
#

package require Fcgi

namespace eval echo-tcl {
    namespace path ::fcgi
}

proc echo-tcl::printEnv {label envArrayName} {
    upvar $envArrayName envArray
    puts "$label:<br>\n<pre>"
    foreach name [lsort [array names envArray]] {
        puts "$name=$envArray($name)"
    }
    puts "</pre><p>"
}

proc echo-tcl::main {} {
    global env
    array set initialEnv [array get env]

    set count 0

    while {[FCGI_Accept] >= 0 } {
        incr count
        puts -nonewline "Content-type: text/html\r\n\r\n"
        puts "<title>FastCGI echo (Tcl)</title>"
        puts "<h1>FastCGI echo (Tcl)</h1>"
        puts "Request number $count <p>"
        if [info exists env(CONTENT_LENGTH)] {
            set len $env(CONTENT_LENGTH)
        } else {
            set len 0
        }
        if {$len == 0} {
            puts "No data from standard input.<p>"
        } else {
            puts "Standard input:<br>\n<pre>"
            for {set i 0} {$i < $len} {incr i} {
                set ch [read stdin 1]
                if {$ch == ""} {
                    puts -nonewline "Error: Not enough bytes received "
                    puts "on standard input<p>"
                    break
                }
                puts -nonewline $ch
            }
            puts "\n</pre><p>"
        }
        printEnv "Request environment" env
        printEnv "Initial environment" initialEnv
    }
}

echo-tcl::main
