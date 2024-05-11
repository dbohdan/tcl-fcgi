# simple source for fcgi
package ifneeded Fcgi 0.5.1 [list source [file join $dir fcgi.tcl]]
package ifneeded Fcgi::helpers 0 [list source [file join $dir fcgi-helpers.tcl]]
