namespace eval fcgi {}
namespace eval fcgi::helpers {}


proc fcgi::helpers::entities s {
    string map {\" &quot; ' &apos; & &amp; < &lt; > &gt;} $s
}


# https://wiki.tcl-lang.org/page/tmpl%5Fparser
proc fcgi::helpers::tmpl_parser template {
    set result {}
    set regExpr {^(.*?)<%(.*?)%>(.*)$}
    set listing "set _output {}\n"
    while {[regexp $regExpr $template match preceding token template]} {
        append listing [list append _output $preceding]\n

        switch -exact -- [string index $token 0] {
            & {
                set code [list [string range $token 1 end]]
                append listing [format \
                    {append _output [%s [expr %s]]} \
                    [namespace current]::entities \
                    $code \
                ]
            }
            = {
                set code [list [string range $token 1 end]]
                append listing [format {append _output [expr %s]} $code]
            }
            ! {
                set code [string range $token 1 end]
                append listing [format {append _output [%s]} $code]
            }
            default {
                append listing $token
            }
        }
        append listing \n
    }

    append listing [list append _output $template]\n

    return $listing
}


proc fcgi::helpers::query-params names {
    set nvlist [ncgi::nvlist]
    set params {}

    foreach name $names {
        dict set params $name {}

        if {[dict exist $nvlist $name]} {
            dict set params $name [dict get $nvlist $name]
        }
    }

    return $params
}


proc fcgi::helpers::validate {check value} {
    if {![regexp {\s} $check]} {
        return [string is $check -strict $value]
    }

    return [uplevel 1 [list {*}$check $value]]
}


proc fcgi::helpers::validate-params {schema params} {
    set failed {}

    foreach {key check default} $schema {
        set good true

        if {[dict exists $params $key]} {
            set command [list \
                [namespace current]::validate \
                $check \
                [dict get $params $key] \
            ]

            set good [uplevel 1 $command]
        } else {
            set good false
        }

        if {!$good} {
            lappend failed $key
            dict set params $key $default
        }
    }

    return [list $params $failed]
}


package provide Fcgi::helpers 0
