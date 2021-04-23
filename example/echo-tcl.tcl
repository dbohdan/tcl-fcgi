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

proc printEnv {label envArrayName} {
    upvar $envArrayName envArray
    fcgi::puts "$label:<br>\n<pre>"
    foreach name [lsort [array names envArray]] {
        fcgi::puts "$name=$envArray($name)"
    }
    fcgi::puts "</pre><p>"
}

foreach name [array names env] {
    set initialEnv($name) $env($name)
}
set count 0
while {[FCGI_Accept] >= 0 } {
    incr count
    fcgi::puts -nonewline "Content-type: text/html\r\n\r\n"
    fcgi::puts "<title>FastCGI echo (Tcl)</title>"
    fcgi::puts "<h1>FastCGI echo (Tcl)</h1>"
    fcgi::puts "Request number $count <p>"
    if [info exists env(CONTENT_LENGTH)] {
        set len $env(CONTENT_LENGTH)
    } else {
        set len 0
    }
    if {$len == 0} {
        fcgi::puts "No data from standard input.<p>"
    } else {
        fcgi::puts "Standard input:<br>\n<pre>"
        for {set i 0} {$i < $len} {incr i} {
            set ch [fcgi::read stdin 1]
            if {$ch == ""} {
                fcgi::puts -nonewline "Error: Not enough bytes received "
                fcgi::puts "on standard input<p>"
                break
	    }
            fcgi::puts -nonewline $ch
	}
        fcgi::puts "\n</pre><p>"
    }
    printEnv "Request environment" env
    printEnv "Initial environment" initialEnv
}
