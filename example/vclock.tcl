#! /usr/bin/env tclsh
# vclock.tcl -- originally borrowed from Don Libes' cgi.tcl but rewritten
#


package require ncgi
package require textutil
package require Fcgi
package require Fcgi::helpers


namespace eval vclock {
    namespace path {::fcgi ::fcgi::helpers}

    variable EXPECT_HOST    http://expect.sourceforge.net
    variable CGITCL         $EXPECT_HOST/cgi.tcl
    variable TEMPLATE [textutil::undent {
        <!doctype html>
        <html><head><title>Virtual Clock</title></head>
        <body>
        <h1>Virtual Clock - fcgi.tcl style</h1>
        <p>Virtual clock has been accessed <%& $counter %> times since
        startup.</p>
        <hr>
        <p>At the tone, the time will be <strong><%& $time %></strong></p>
        <% if {[dict get $query debug]} { %>
            <pre>     Query: <%& $query %>
            Failed: <%& $failed %></pre>
        <% } %>
        <hr>
        <h2>Set Clock Format</h2>
        <form>
        Show:
        <% foreach name {day month day-of-month year} { %>
          <input type="checkbox" id="<%= $name %>" name="<%= $name %>"
                 <%= [dict get $query $name] ? {checked} : {} %>>
          <label for="<%= $name %>"><%= $name %></label>
        <% } %>
        <br>
        Time style:
        <% foreach value {12-hour 24-hour} { %>
          <input type="radio" id="<%= $value %>" name="type" value="<%= $value %>"
                 <%= [dict get $query type] eq $value ? {checked} : {} %>>
          <label for="<%= $value %>"><%= $value %></label>
        <% } %>
        <br>
        <input type="reset">
        <input type="submit">
        </form>
        <hr>
        See Don Libes' cgi.tcl and original vclock
        at the <a href="<%& $CGITCL %>"><%& $CGITCL %></a>
        </body>
        </html>
    }]
}


proc vclock::main {} {
    variable CGITCL
    variable TEMPLATE

    proc page {query failed counter time CGITCL} [tmpl_parser $TEMPLATE]

    set counter 0

    while {[FCGI_Accept] >= 0} {
        incr counter

        puts "Content-Type: text/html\r\n\r\n"

        lassign [validate-params {
            day          boolean                   false
            day-of-month boolean                   false
            debug        boolean                   false
            month        boolean                   false
            type         {regexp ^(?:12|24)-hour$} 24-hour
            year         boolean                   false
        } [query-params {day day-of-month debug month type year}]] query failed

        set format [construct-format $query]
        set time [clock format [clock seconds] -format $format]

        puts [page $query $failed $counter $time $CGITCL]

        ncgi::reset
    } ;# while {[FCGI_Accept] >= 0}
}


proc vclock::construct-format query {
    if {[dict get $query type] eq {}} {
        return {%r %a %h %d '%y}
    }

    set format [expr {
        [dict get $query type] eq {12-hour} ? {%r} : {%T}
    }]

    foreach {name fragment} {
        day { %a}
        month { %h}
        day-of-month { %d}
        year { '%y}
    } {
        if {[dict get $query $name] ne {}} {
            append format $fragment
        }
    }

    return $format
}


# If this is the main script...
if {[info exists argv0] && ([file tail [info script]] eq [file tail $argv0])} {
    vclock::main
}
