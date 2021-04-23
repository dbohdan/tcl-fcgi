#! /usr/bin/env tclsh
#
#  echo-cgi --
#

package require cgi
package require Fcgi


set count 0
while {[FCGI_Accept] >= 0 } {
  cgi_eval {
    incr count
    cgi_title "fcgi.tcl: echo-cgi.fcg"
    cgi_body {
      cgi_h1 "fcgi.tcl"
      cgi_h2 "echo-cgi.fcg: request number $count"
      cgi_parray env
    }
  }
}
