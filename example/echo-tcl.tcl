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
package require Fcgi::helpers

namespace eval echo-tcl {
    namespace path {::fcgi ::fcgi::helpers}
}

proc echo-tcl::main {} {
    global env
    set initialEnv [array get env]

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

            set buf [read stdin $len]
            if {[string length $buf] == $len} {
                puts [entities $buf]\n
            } else {
                puts "Error: Not enough bytes received on standard input"
            }

            puts </pre><p>
        }

        set request {}
        foreach name [array names env] {
            if {![dict exists $initialEnv $name]} {
                dict set request $name $env($name)
            }
        }
        puts "<h2>Request environment</h2>\n[htmlize-dict $request]"
        puts "<h2>Initial environment</h2>\n[htmlize-dict $initialEnv]"
    }
}

proc echo-tcl::htmlize-dict dict {
    set s <dl>\n
    dict for {k v} $dict {
        append s <dt>[entities $k]</dt><dd>[entities $v]</dd>\n
    }
    append s </dl>
}

echo-tcl::main
