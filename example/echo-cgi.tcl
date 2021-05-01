#! /usr/bin/env tclsh
#
#  echo-cgi --
#

package require html
package require ncgi
package require Fcgi

set count 0

while {[FCGI_Accept] >= 0 } {
  incr count

  puts "Content-Type: text/html\r\n\r\n"
  html::init

  puts "<!doctype html>"
  puts [html::head {fcgi.tcl: echo-cgi.fcg}]
  puts [html::openTag body]
  puts [html::h1 {fcgi.tcl}]
  puts [html::h2 "echo-cgi.fcg: request number $count"]
  puts [html::tableFromArray env]
  puts [html::closeTag]
  puts [html::closeTag]
}
