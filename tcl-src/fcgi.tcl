###############################################################################
#
# fcgi.tcl
#
# Copyright 1998, Tom Poindexter,  all rights reserved
# tpoindex@nyx.net
# http://www.nyx.net/~tpoindex
#  see the file LICENSE.TERMS for complete copyright and licensing info
#
#  FastCGI interface for Tcl
#    Extended Tcl (aka Tclx) is required for 'AppClass' style connections,
#    (the 'package require Tclx' is near the bottom of this file, and only
#    used when needed.)
#    Tcl 8.0+ is required, as fcgi.tcl uses namespace and binary commands.
#


package provide Fcgi 0.6.0

namespace eval fcgi {

variable fcgi
global env

###############################################################################
# define fcgi constants (from fastcgi.h)

# Values for protocol info
set fcgi(FCGI_LISTENSOCK_FILENO) 0
set fcgi(FCGI_MAX_LENGTH)        [expr 0xffff]
set fcgi(FCGI_HEADER_LEN)        8
set fcgi(FCGI_VERSION_1)         1

# Values for type component of FCGI_Header
set fcgi(FCGI_BEGIN_REQUEST)       1
set fcgi(FCGI_ABORT_REQUEST)       2
set fcgi(FCGI_END_REQUEST)         3
set fcgi(FCGI_PARAMS)              4
set fcgi(FCGI_STDIN)               5
set fcgi(FCGI_STDOUT)              6
set fcgi(FCGI_STDERR)              7
set fcgi(FCGI_DATA)                8
set fcgi(FCGI_GET_VALUES)          9
set fcgi(FCGI_GET_VALUES_RESULT)  10
set fcgi(FCGI_UNKNOWN_TYPE)       11

# Value for requestId component of FCGI_Header
set fcgi(FCGI_NULL_REQUEST_ID)     0

# Mask for flags component of FCGI_BeginRequestBody
set fcgi(FCGI_KEEP_CONN)  1

# Values for role component of FCGI_BeginRequestBody
set fcgi(FCGI_RESPONDER)  1
set fcgi(FCGI_AUTHORIZER) 2
set fcgi(FCGI_FILTER)     3

# Values for protocolStatus component of FCGI_EndRequestBody
set fcgi(FCGI_REQUEST_COMPLETE) 0
set fcgi(FCGI_CANT_MPX_CONN)    1
set fcgi(FCGI_OVERLOADED)       2
set fcgi(FCGI_UNKNOWN_ROLE)     3

# Variable names for FCGI_GET_VALUES / FCGI_GET_VALUES_RESULT records
set fcgi(FCGI_MAX_CONNS)  "FCGI_MAX_CONNS"
set fcgi(FCGI_MAX_REQS)   "FCGI_MAX_REQS"
set fcgi(FCGI_MPXS_CONNS) "FCGI_MPXS_CONNS"

###############################################################################
# define fcgi state variables

set fcgi(requestId)     -1		;# current requestId in progress
set fcgi(origEnv)    [array names env]	;# list of orignal env names
set fcgi(listenSock)    -1		;# socket on which we listen
set fcgi(acceptCmd)     -1		;# command to accept new sock
set fcgi(newSock)       -1		;# new client socket
global fcgiNewSock
set fcgiNewSock         -1		;# var to wait on Tcl socket
set fcgi(newClient)     ""		;# ip of client that connected
set fcgi(bufSize)       4096		;# stdout/stderr buffer size
set fcgi(notFcgi)	0		;# if app is running as normal CGI


###############################################################################
# define fcgi mgmt variables responses

set fcgi(fcgi_max_conns)     1		;# only one connection at a time
set fcgi(fcgi_max_reqs)      1		;# only one request at a time
set fcgi(fcgi_mpxs_conns)    0		;# don't multiplex connections

###############################################################################
# per request variables

# these are shown here as comments, actually set in FCGI_Accept
#set fcgi($requestId,sock)      -1	;# socket for connection
#set fcgi($requestId,env)       ""	;# environment
#set fcgi($requestId,paramsEof) 0	;# environment eof marker
#set fcgi($requestId,stdin)     ""	;# stdin buffer
#set fcgi($requestId,stdinEof)  0	;# stdin eof marker
#set fcgi($requestId,data)      ""	;# fcgi data buffer
#set fcgi($requestId,dataEof)   0	;# fcgi data eof marker
#set fcgi($requestId,dataRedir) 0	;# fcgi data redirected to stdin
#set fcgi($requestId,stdout)    ""	;# stdout buffer
#set fcgi($requestId,stdoutFlg) 0       ;# stdout written flag
#set fcgi($requestId,stderr)    ""	;# stderr buffer
#set fcgi($requestId,stderrFlg) 0       ;# stderr written flag
#set fcgi($requestId,keepConn)  0	;# keep connection
#set fcgi($requestId,exitCode)  0	;# exit code
#set fcgi($requestId,role)      0	;# fcgi role

# rename Tcl io commands so we can redefine them as fcgi aware
rename gets  _gets_tcl
rename read  _read_tcl
rename flush _flush_tcl
rename puts  _puts_tcl
rename eof   _eof_tcl


}   ;# end of namespace eval fcgi



###############################################################################
#
# replacement stdio procs to act on fcgi stdio/data stream as well as files
#
###############################################################################

###############################################################################
# fcgi "gets" wrapper proc

proc fcgi::gets {args} {
  variable fcgi
  set requestId $fcgi(requestId)
  if {$requestId == -1} {
    return [uplevel 1 fcgi::_gets_tcl $args]
  }
  if {[lindex $args 0] == "stdin"} {
    if {$fcgi($requestId,dataRedir) && ! $fcgi($requestId,dataEof)} {
      set rc [processFcgiStream $fcgi($requestId,sock) $requestId "data"]
    } elseif {! $fcgi($requestId,stdinEof)} {
      set rc [processFcgiStream $fcgi($requestId,sock) $requestId "stdin"]
    } else {
      set rc 1	;# force "no error"
    }
    if {$rc <= 0} {
      if {[llength $args] > 1} {
	return 0
      } else {
        return ""
      }
    }
    set idx [string first \n $fcgi($requestId,stdin)]
    if {$idx == -1} {
      set idx [string length $fcgi($requestId,stdin)]
    }
    incr idx -1
    set msg [string range $fcgi($requestId,stdin) 0 $idx]
    incr idx 2
    set fcgi($requestId,stdin) [string range $fcgi($requestId,stdin) $idx end]
    if {[llength $args] > 1} {
      uplevel 1 set [list [lindex $args 1]] [list $msg]
      return [string length $msg]
    } else {
      return $msg
    }
  } else {
    return [uplevel 1 fcgi::_gets_tcl $args]
  }
}


###############################################################################
# fcgi "read" wrapper proc

proc fcgi::read {args} {
  variable fcgi
  set requestId $fcgi(requestId)
  if {$requestId == -1} {
    return [uplevel 1 fcgi::_read_tcl $args]
  }

  # fill stdin or data buffer if stdin channel
  if {([lindex $args 0] == "stdin") || \
      ([lindex $args 0] == "-nonewline" &&[lindex $args 1] == "stdin")} {

    if {$fcgi($requestId,dataRedir) && ! $fcgi($requestId,dataEof)} {
      set rc [processFcgiStream $fcgi($requestId,sock) $requestId "data"]
    } elseif {! $fcgi($requestId,stdinEof)} {
      set rc [processFcgiStream $fcgi($requestId,sock) $requestId "stdin"]
    } else {
      set rc 1	;# force "no error"
    }
    if {$rc <= 0} {
      return ""
    }
  }

  if {[lindex $args 0] == "-nonewline"} {
    if {[lindex $args 1] == "stdin"} {
      # read from stdin buf until eof, chop last nl
      set msg [string trim $fcgi($requestId,stdin) \nl]
      returm $msg
    } else {
      return [uplevel 1 fcgi::_read_tcl $args]
    }
  } else  {
    if {[lindex $args 0] == "stdin"} {
      # read from stdin buf specific num of bytes
      if {[llength $args] > 1} {
        set num 0
	scan [lindex $args 1] %d num
        set msg [string range $fcgi($requestId,stdin) 0 [expr $num - 1]]
        set fcgi($requestId,stdin) \
			       [string range $fcgi($requestId,stdin) $num end]
      } else {
	set msg $fcgi($requestId,stdin)
	set fcgi($requestId,stdin) ""
      }
      return $msg
    } else {
      return [uplevel 1 fcgi::_read_tcl $args]
    }
  }
}


###############################################################################
# fcgi "flush" wrapper proc

proc fcgi::flush {file} {
  variable fcgi
  set requestId $fcgi(requestId)
  if {$requestId == -1} {
    return [uplevel 1 fcgi::_flush_tcl $file]
  }
  if {$file == "stdout" || $file == "stderr"} {
    set num [string length $fcgi($requestId,$file)]
    while {$num > 0} {
      set num [expr $num<$fcgi(FCGI_MAX_LENGTH) ? $num : $fcgi(FCGI_MAX_LENGTH)]
      set msg [string range $fcgi($requestId,$file) 0 [expr $num - 1]]
      set fcgi($requestId,$file) \
			      [string range $fcgi($requestId,$file) $num end]
      if {$file == "stdout"} {
	set type $fcgi(FCGI_STDOUT)
      } else {
	set type $fcgi(FCGI_STDERR)
      }
      writeFcgiRecord $fcgi($requestId,sock) $fcgi(FCGI_VERSION_1) $type \
		      $requestId $msg
      set num [string length $fcgi($requestId,$file)]
    }
  } else {
    uplevel 1 fcgi::_flush_tcl $file
  }
  return ""
}



###############################################################################
# fcgi "puts" wrapper proc

proc fcgi::puts {args} {
  variable fcgi
  set requestId $fcgi(requestId)
  if {$requestId == -1} {
    return [uplevel 1 fcgi::_puts_tcl $args]
  }
  switch [llength $args] {
    1 {
      append fcgi($requestId,stdout) [lindex $args 0] \n
      set file stdout
    }
    2 {
      if {[lindex $args 0] == "-nonewline"} {
        append fcgi($requestId,stdout) [lindex $args 1]
        set file stdout
      } else {
        set file [lindex $args 0]
        if {$file == "stdout" || $file == "stderr"} {
          append fcgi($requestId,$file) [lindex $args 1] \n
        } else {
          uplevel 1 fcgi::_puts_tcl $args
        }
      }
    }
    default {
      set file [lindex $args 1]
      if {[lindex $args 0] == "-nonewline" && \
	 ($file == "stdout" || $file == "stderr")} {
        append fcgi($requestId,$file) [lindex $args 2]
      } else {
        uplevel 1 fcgi::_puts_tcl $args
      }
    }
  }

  # set "written to" flag and check if flush needed
  if {[string compare $file "stdout"] == 0 || \
      [string compare $file "stderr"] == 0} {
    set fcgi($requestId,${file}Flg) 1
    if {[string length $fcgi($requestId,$file)] > $fcgi(bufSize)} {
      flush $file
    }
  }
  return ""

}


###############################################################################
# fcgi "eof" wrapper proc

proc fcgi::eof {file} {
  variable fcgi
  set requestId $fcgi(requestId)
  if {$requestId == -1} {
    return [uplevel 1 fcgi::_eof_tcl $file]
  }
  if {$file == "stdin"} {
    if {[string length $fcgi($requestId,$file)] == 0 && \
	$fcgi($requestId,stdinEof)} {
      return 1
    } else {
      return 0
    }
  } else {
    return [uplevel 1 fcgi::_eof_tcl $file]
  }
}


###############################################################################
#
# fcgi support routines
#
###############################################################################


###############################################################################
# read fcgi record

proc fcgi::readFcgiRecord {sock} {
  variable fcgi
  set msg ""

  while {[string length $msg] != $fcgi(FCGI_HEADER_LEN)} {
    append msg \
	[_read_tcl $sock [expr $fcgi(FCGI_HEADER_LEN) - [string length $msg]]]
  }

  set version         0
  set type            0
  set requestId       0
  set contentLength   0
  set paddingLength   0
  set reserved        0

  # read the header
  binary scan $msg ccSScc version type requestId contentLength \
                          paddingLength reserved

  # convert everything to unsigned int values
  set version       [expr ($version       + 0x100)   % 0x100]
  set type          [expr ($type          + 0x100)   % 0x100]
  set requestId     [expr ($requestId     + 0x10000) % 0x10000]
  set contentLength [expr ($contentLength + 0x10000) % 0x10000]
  set paddingLength [expr ($paddingLength + 0x100)   % 0x100]

  # read msg content
  set content ""
  while {[string length $content] != $contentLength} {
    append content \
	[_read_tcl $sock [expr $contentLength - [string length $content]]]
  }

  # read msg padding
  set padding ""
  while {[string length $padding] != $paddingLength} {
    append padding \
	[_read_tcl $sock [expr $paddingLength - [string length $padding]]]
  }

  return [list $version $type $requestId $contentLength $content]
}


###############################################################################
# write fcgi record

proc fcgi::writeFcgiRecord {sock version type requestId content} {

  set contentLength [string length $content]
  # ccSScc = version type requestId contentLength padding reserved

  catch {
    _puts_tcl -nonewline $sock \
	   [binary format ccSScc $version $type $requestId $contentLength 0 0]
    _puts_tcl -nonewline $sock $content
    _flush_tcl $sock
  }

}


###############################################################################
# scan fcgi request body
#   input: message string of type FCGI_BEGIN_REQUEST

proc fcgi::scanFcgiRequestBody {msg} {
  set role   0
  set flags  0
  # last 5 bytes are reserved
  binary scan $msg Scc5 role flags reserved
  set role  [expr ($role  + 0x10000) % 0x10000]
  set flags [expr ($flags + 0x100)   % 0x100]
  return [list $role $flags]
}


###############################################################################
# format fcgi end request response

proc fcgi::formatFcgiEndRequest {appStatus protocolStatus} {
  return [binary format Icc3 $appStatus $protocolStatus {0 0 0}]
}


###############################################################################
# format fcgi unknown type response

proc fcgi::formatFcgiUnknownType {type} {
  return [binary format cc7 $type {0 0 0 0 0 0 0}]
}


###############################################################################
# scan fcgi name value pair

proc fcgi::scanFcgiNameValue {msg} {

  # get name len
  set nlen 0
  binary scan $msg c nlen
  set nlen [expr ($nlen + 0x100) % 0x100]
  if {$nlen > 127} {
    binary scan $msg I nlen
    set nlen [expr $nlen & 0x7fffff]
    set nlenLen 4
  } else {
    set nlenLen 1
  }

  # get value len
  set vlen 0
  binary scan $msg "x${nlenLen}c" vlen
  set vlen [expr ($vlen + 0x100) % 0x100]
  if {$vlen > 127} {
    binary scan $msg "x${nlenLen}I" vlen
    set vlen [expr $vlen & 0x7fffff]
    set vlenLen 4
  } else {
    set vlenLen 1
  }

  # get name and value
  set fmt [format x%dx%da%da%d $nlenLen $vlenLen $nlen $vlen]
  set name  ""
  set value ""
  binary scan $msg $fmt name value
  set totLen [expr $nlenLen + $vlenLen + $nlen + $vlen]
  return [list $totLen $name $value]
}


###############################################################################
# format fcgi name value pair

proc fcgi::formatFcgiNameValue {name value} {
  set nlen [string length $name]
  set vlen [string length $value]
  if {$nlen > 127} {
    set nlenFmt I
    set nlen [expr $nlen | 0x80000000]
  } else {
    set nlenFmt c
  }
  if {$vlen > 127} {
    set vlenFmt I
    set vlen [expr $vlen | 0x80000000]
  } else {
    set vlenFmt c
  }
  set fmt [format %s%sa%da%d $nlenFmt $vlenFmt $nlen $vlen]
  return [binary format $fmt $nlen $vlen $name $value]
}


###############################################################################
# respond to mgmt record requests

proc fcgi::respondFcgiMgmtRecord {s msg} {
  variable fcgi
  set requestId $fcgi(requestId)

  set reply ""

  while {[string length $msg] > 0} {
    set nameValue [scanFcgiNameValue $msg]
    set totLen [lindex $nameValue 0]
    set name   [lindex $nameValue 1]
    set value  [lindex $nameValue 2]
    set msg [string range $msg $totLen end]

    # "open" style of switch command
    switch -- $name \
      $fcgi(FCGI_MAX_CONNS)  {
	 append reply [formatFcgiNameValue $name $fcgi(fcgi_max_conns)]
      } \
      $fcgi(FCGI_MAX_REQS) {
	 append reply [formatFcgiNameValue $name $fcgi(fcgi_max_reqs)]
      } \
      $fcgi(FCGI_MPXS_CONNS) {
	 append reply [formatFcgiNameValue $name $fcgi(fcgi_mpxs_conns)]
      } \
      default {
      }

  }

  if {[string length $reply] > 0} {
     writeFcgiRecord $fcgi($requestId,sock) $fcgi(FCGI_VERSION_1) \
	     $fcgi(FCGI_GET_VALUES_RESULT) 0 $reply
  }
}


###############################################################################
# process fcgi header / new request
# returns list: requestId role flags - new request
#        {-1 0 0} - server tried to multiplex request
#        { 0 0 0} - socket closed

proc fcgi::getFcgiBeginRequest {sock} {
  variable fcgi

  set type -1
  while {$type != $fcgi(FCGI_BEGIN_REQUEST)} {
    if {[catch {set msg [readFcgiRecord $sock]}]} {
      # read error
      return {0 0 0}
    }
    set version       [lindex $msg 0]
    set type          [lindex $msg 1]
    set requestId     [lindex $msg 2]
    set contentLength [lindex $msg 3]
    set content       [lindex $msg 4]
    if {$type == $fcgi(FCGI_BEGIN_REQUEST)} {
      set msg [scanFcgiRequestBody $content]
      set role  [lindex $msg 0]
      set flags [lindex $msg 1]
      return [list $requestId $role $flags]
    } elseif {$requestId == 0 || $type == $fcgi(FCGI_GET_VALUES)} {
	respondFcgiMgmtRecord $sock $content
    } else {
      writeFcgiRecord $sock $version $fcgi(FCGI_UNKNOWN_TYPE) 0 \
						 [formatFcgiUnknownType $type]
      return {-1 0 0}
    }
  }
}


###############################################################################
# process fcgi connections
# returns 1 - "waitfor" stream completed
#        -1 - server tried to multiplex request or abort request
#         0 - socket closed

proc fcgi::processFcgiStream {sock requestId waitfor} {
  variable fcgi

  switch -- $waitfor {
    params {set waitfor fcgi($requestId,paramsEof)}
    stdin  {set waitfor fcgi($requestId,stdinEof)}
    data   {set waitfor fcgi($requestId,dataEof)}
    default {return -1}
  }

  while {! [set $waitfor]} {

    if {[catch {set msg [readFcgiRecord $sock]}]} {
      # read error
      return 0
    }
    set version       [lindex $msg 0]
    set type          [lindex $msg 1]
    set requestId     [lindex $msg 2]
    set contentLength [lindex $msg 3]
    set content       [lindex $msg 4]

    if {$requestId == 0} {
      respondFcgiMgmtRecord $sock $content
      continue
    }

    if {$requestId != $fcgi(requestId)} {
      writeFcgiRecord $sock $version $fcgi(FCGI_END_REQUEST) $requestId \
		 [formatFcgiEndRequest 0 $fcgi(FCGI_CANT_MPX_CONN)]
      return -1
    }

    # "open" style of switch command
    switch -- $type \
      $fcgi(FCGI_PARAMS) {
	if {$contentLength == 0} {
          set fcgi($requestId,paramsEof) 1
	} else {
	  while {[string length $content] > 0} {
            set msg [scanFcgiNameValue $content]
            lappend fcgi($requestId,env)  [lindex $msg 1] [lindex $msg 2]
	    set content [string range $content [lindex $msg 0] end]
	  }
	}
      } \
      $fcgi(FCGI_STDIN) {
	if {$contentLength == 0} {
	  set fcgi($requestId,stdinEof) 1
	} else {
	  if {!$fcgi($requestId,dataRedir)} {
	    append fcgi($requestId,stdin) $content
	  }
	}
      } \
      $fcgi(FCGI_DATA)   {
	if {$contentLength == 0} {
	  set fcgi($requestId,dataEof) 1
	  if {$fcgi($requestId,dataRedir)} {
	    set fcgi($requestId,stdin) $fcgi($requestId,data)
	    set fcgi($requestId,stdinEof) 1
	  }
	} else {
	  append fcgi($requestId,data) $content
	}
      } \
      $fcgi(FCGI_GET_VALUES) {
	respondFcgiMgmtRecord $sock $content
      } \
      $fcgi(FCGI_ABORT_REQUEST) {
        writeFcgiRecord $sock $fcgi(FCGI_VERSION_1) \
             $fcgi(FCGI_END_REQUEST) $requestId \
             [formatFcgiEndRequest 0 $fcgi(FCGI_REQUEST_COMPLETE)]

	return -1
      } \
      $fcgi(FCGI_END_REQUEST) - \
      $fcgi(FCGI_UNKNOWN_TYPE) - \
      $fcgi(FCGI_STDOUT) - \
      $fcgi(FCGI_STDERR) {
	# ignore these packets
      } \
      default {
	# send back unknown type
        writeFcgiRecord $sock $version $fcgi(FCGI_UNKNOWN_TYPE) $requestId \
						 [formatFcgiUnknownType $type]
      }
    # end of switch
  }

  return 1
}


###############################################################################
# set up env for new connection

proc fcgi::setupFcgiEnv {requestId} {
  variable fcgi
  global env

  # unset all but orignal env names
  foreach {name} [array names env] {
    if {[lsearch $fcgi(origEnv) $name] == -1} {
      unset env($name)
    }
  }

  # add in env for this fcgi connection
  foreach {name value} $fcgi($requestId,env) {
    set env($name) $value
  }
}


###############################################################################
# clean up per request fcgi variables

proc fcgi::cleanUpFcgi {requestId} {
  variable fcgi

  catch {unset fcgi($requestId,sock)     }
  catch {unset fcgi($requestId,env)      }
  catch {unset fcgi($requestId,paramsEof)}
  catch {unset fcgi($requestId,stdin)    }
  catch {unset fcgi($requestId,stdinEof) }
  catch {unset fcgi($requestId,data)     }
  catch {unset fcgi($requestId,dataEof)  }
  catch {unset fcgi($requestId,dataRedir)}
  catch {unset fcgi($requestId,stdout)   }
  catch {unset fcgi($requestId,stdoutFlg)}
  catch {unset fcgi($requestId,stderr)   }
  catch {unset fcgi($requestId,stderrFlg)}
  catch {unset fcgi($requestId,keepConn) }
  catch {unset fcgi($requestId,exitCode) }
  catch {unset fcgi($requestId,role)     }

}


###############################################################################
# reset of cgi.tcl environment

proc fcgi::resetCgiEnv {} {

  # if also using cgi.tcl, get the _cgi global array, and save beginning values.
  # cgi.tcl uses the _cgi array to save state information, which needs to
  # be reset on each FCGI_Accept call

  global _cgi
  variable fcgi_cgi

  if {[array exists _cgi]} {
    # try to use cgi.tcl reset environment, otherwise do it ourselves
    if {[catch {cgi_reset_env}]} {
      # set _cgi back to beginning values
      if {![array exists fcgi_cgi]} {
	array set fcgi_cgi [array get _cgi]
      }
      catch {unset _cgi}
      array set _cgi [array get fcgi_cgi]
      # unset other _cgi_xxxx vars
      # untouched are: _cgi_link _cgi_imglink _cgi_link_url
      set cgi_vars {_cgi_uservar _cgi_cookie _cgi_cookie_shadowed _cgi_userfile}
      foreach v $cgi_vars {
        global $v
        catch {unset $v}
      }
    }
  }

}


###############################################################################
#
# application interfaces
#
###############################################################################


###############################################################################
# accept a new fcgi connection, this is the primary call from the application

proc fcgi::FCGI_Accept {} {
  variable fcgi

  global env
  set requestId $fcgi(requestId)

  # if we started with stdin as a real stdin, then fail second time around
  if {$fcgi(notFcgi)} {
    return -1
  }

  # flush and pending request
  if {$fcgi(requestId) != -1} {
    FCGI_Finish
  }

  # execute the accept command, either 'fcgiTclxAccept' or 'fcgiSockAccept'
  set sock [$fcgi(acceptCmd) $fcgi(listenSock)]

  # if we get a null back from accept, means we're running as plain CGI
  if {[string length $sock] == 0} {
    # set to fail on second time
    set fcgi(notFcgi) 1

    # set role as responder
    set env(FCGI_ROLE) RESPONDER

    return 0
  }

  # get the begin request message
  set newFcgi [getFcgiBeginRequest $sock]

  if {[string compare $newFcgi 0] == 0} {
    return -1
  } elseif {[string compare $newFcgi -1] == 0} {
    return  -1
  }
  set requestId [lindex $newFcgi 0]
  set role      [lindex $newFcgi 1]
  set flags     [lindex $newFcgi 2]

  if {$requestId == -1} {
    return -1
  }

  set fcgi(requestId)            $requestId
  set fcgi($requestId,sock)      $sock	;# socket for connection
  set fcgi($requestId,env)       ""	;# environment
  set fcgi($requestId,paramsEof) 0	;# environment eof marker
  set fcgi($requestId,stdin)     ""	;# stdin buffer
  set fcgi($requestId,stdinEof)  0	;# stdin eof marker
  set fcgi($requestId,data)      ""	;# fcgi data buffer
  set fcgi($requestId,dataEof)   0	;# fcgi data eof marker
  set fcgi($requestId,dataRedir) 0	;# fcgi data redirected to stdin
  set fcgi($requestId,stdout)    ""	;# stdout buffer
  set fcgi($requestId,stdoutFlg) 0	;# stdout written flag
  set fcgi($requestId,stderr)    ""	;# stderr buffer
  set fcgi($requestId,stderrFlg) 0	;# stderr written flag
  set fcgi($requestId,keepConn)  $flags	;# keep connection
  set fcgi($requestId,exitCode)  0	;# exit code
  set fcgi($requestId,role)      $role	;# fcgi role

  # get fcgi params streams until no more params
  set rc [processFcgiStream $sock $requestId "params"]

  if {$rc <= 0} {
    cleanUpFcgi $requestId
    return -1
  }

  setupFcgiEnv $requestId

  # "open" style of switch command
  switch -- $fcgi($requestId,role) \
    $fcgi(FCGI_RESPONDER)  {
      set env(FCGI_ROLE) RESPONDER
    } \
    $fcgi(FCGI_AUTHORIZER) {
      set env(FCGI_ROLE) AUTHORIZER
    } \
    $fcgi(FCGI_FILTER)     {
      set env(FCGI_ROLE) FILTER
    } \
    default {
      set env(FCGI_ROLE) ""
    }
  # end of switch


  # cause cgi.tcl to be sourced, if not already sourced, and reset cgi.tcl
  catch {cgi_lt}
  resetCgiEnv

  return 0
}


###############################################################################
# finish fcgi connection

proc fcgi::FCGI_Finish {} {
  variable fcgi
  set requestId $fcgi(requestId)

  # write stdout and stderr bufs
  foreach {file type} {stdout FCGI_STDOUT stderr FCGI_STDERR} {
    if {$fcgi($requestId,${file}Flg)} {
      flush $file
      # send zero length as eof
      writeFcgiRecord $fcgi($requestId,sock) $fcgi(FCGI_VERSION_1) \
	      $fcgi($type) $requestId ""
    }
  }

  # write end request
  writeFcgiRecord $fcgi($requestId,sock) $fcgi(FCGI_VERSION_1) \
    $fcgi(FCGI_END_REQUEST) $requestId \
    [formatFcgiEndRequest $fcgi($requestId,exitCode) \
		          $fcgi(FCGI_REQUEST_COMPLETE)]

  # check to teardown socket
  if {! ($fcgi($requestId,keepConn) & $fcgi(FCGI_KEEP_CONN) )} {
    close $fcgi($requestId,sock)
  }

  # clean up
  cleanUpFcgi $requestId

  set fcgi(requestId)  -1

}


###############################################################################
# set exit status for fcgi

proc fcgi::FCGI_SetExitStatus {status} {
  variable fcgi

  set requestId $fcgi(requestId)
  set fcgi($requestId,exitCode) $status
  return ""
}


###############################################################################
# start filter data

proc fcgi::FCGI_StartFilterData {} {
  variable fcgi

  set requestId $fcgi(requestId)
  set fcgi($requestId,stdin)    $fcgi($requestId,data)
  set fcgi($requestId,stdinEof) $fcgi($requestId,dataEof)
  set fcgi($requestId,dataRedir) 1
  return ""
}


###############################################################################
# set buffer size, valid sizes: 0 to FCGI_MAX_LENGTH

proc fcgi::FCGI_SetBufSize {size} {
  variable fcgi

  set newSize -1
  catch {scan $size %d newSize}
  if {$newSize >= 0 && $newSize <= $fcgi(FCGI_MAX_LENGTH)} {
    set fcgi(bufSize) $newSize
  }
  return $fcgi(bufSize)
}




###############################################################################
#
# start up fcgi processing
#
###############################################################################

namespace eval fcgi {

variable fcgi
global env


###############################################################################
# procs to handle native Tcl socket accepts & Tclx accepts
#

# callback proc from Tcl's 'socket -server'
proc ::fcgiAccept {sock client port} {
  global fcgiNewSock
  variable fcgi
  set fcgi(newClient) $client
  set fcgiNewSock $sock
  update
}

# blocking 'accept' for Tcl sockets
proc ::fcgiSockAccept {sock} {
  global fcgiNewSock
  variable fcgi
  vwait fcgiNewSock
  set fcgi(newSock) $fcgiNewSock
  fconfigure $fcgi(newSock) -translation binary
  return $fcgiNewSock
}

# blocking 'accept' for TclX sockets
proc ::fcgiTclxAccept {sock} {
  variable fcgi
  set fcgi(newSock)   ""
  set fcgi(newClient) ""
  # watch for failure, if so then we probably started with stdin = real stdin
  if {[catch {set fcgi(newSock) [server_accept $sock]}] == 0} {
    # we got a good accept, change channel to binary
    fconfigure $fcgi(newSock) -translation binary
    catch {set fcgi(newClient) [lindex [fconfigure -socket $fcgi(newSock)] 0]}
  }
  return $fcgi(newSock)
}



###############################################################################
#    look for port on which to listen, either as argument(-port) or env(PORT)
#    if neither, then use file descriptor 0 as server port

set port -1

# check for argv "-port xxx" first
for {set i 0} {$i < $::argc} {incr i} {
  if {[string compare [lindex $::argv $i] "-port"] == 0} {
    incr i
    scan [lindex $::argv $i] %d port
  }
}

# next, check env(PORT)
if {$port < 0} {
  if {[info exists env(PORT)]} {
    scan $env(PORT) %d port
  }
}


# if port was found, then open a server socket on which to listen
# if no port was found, assume we started with as a forked process with
# stdin = unix domain socket from apache's mod_fastcgi.

if {$port < 0} {
  # we use the fine Tclx extension for this style of connection
  package require Tclx
  set fcgi(listenSock) stdin
  set fcgi(acceptCmd)  fcgiTclxAccept
} else {
  set fcgi(listenSock) [socket -server fcgiAccept $port]
  set fcgi(acceptCmd)  fcgiSockAccept
}



# export applications and io wrapper commands
namespace export FCGI_Accept FCGI_Finish FCGI_SetExitStatus \
		 FCGI_StartFilterData FCGI_SetBufSize
namespace export gets read flush puts eof

}   ;# end of namespace eval fcgi


# https://groups.google.com/g/comp.lang.tcl/c/z6XXz2yKeRo/m/64Rc-0cHJFoJ
catch auto_import
rename auto_import FCGI_auto_import

# make the application use fcgi wrappers for these io commands
namespace import -force fcgi::gets
namespace import -force fcgi::read
namespace import -force fcgi::flush
namespace import -force fcgi::puts
namespace import -force fcgi::eof

# import the application fcgi commands
namespace import fcgi::FCGI_Accept
namespace import fcgi::FCGI_Finish
namespace import fcgi::FCGI_SetExitStatus
namespace import fcgi::FCGI_StartFilterData
namespace import fcgi::FCGI_SetBufSize

rename FCGI_auto_import auto_import


# finis
