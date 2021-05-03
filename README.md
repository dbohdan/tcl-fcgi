# FastCGI interface for Tcl 8

Copyright 1998 Tom Poindexter, all rights reserved.
Portions copyright 2021 D. Bohdan.

Fcgi.tcl is distributed under a BSD-style license like Tcl's own.
See the file [LICENSE.TERMS](LICENSE.TERMS) for details.


## What is Fcgi.tcl?

Fcgi.tcl is a Tcl interface for the FastCGI protocol.  Fcgi.tcl is designed to
work with Tcl 8.0.  Fcgi.tcl comes in two flavors: 

* A Tcl source version which is written in 100% pure Tcl, optionally using the
  Extended Tcl (TclX) extension for certain types of FastCGI connections.  This
  is what you will find in this repository.

* A Tcl C extension version, which uses library code from the FastCGI
  Developer's Kit.  It is available
  [elsewhere](https://wiki.tcl-lang.org/page/FastCGI).

Each flavor provides the same programming interface for application programs.
See the file [INSTALL](INSTALL) for more information about the two flavors.

FastCGI is a protocol to allow CGI-style programs to be started as a server, 
avoiding the CGI overhead of process creation and program loading.  FastCGI 
servers can be run on the same machine as your web server or run on different
machines.  For more details on FastCGI, see
[Wikipedia](https://en.wikipedia.org/wiki/FastCGI).

The FastCGI Developer's Kit contained an interface for Tcl 7.4. Unfortunately,
that interface was never updated for newer versions of Tcl.  Fcgi.tcl was
written to keep up with the lastest Tcl releases.


## Requirements

* Tcl 8.0.3 (Tcl 8.5 for `Fcgi::helpers` and the examples)
* [TclX](https://wiki.tcl-lang.org/page/TclX) (optional)
* A Web server supporting the FastCGI protocol:
    * Apache 2 using the [mod\_fcgi](https://httpd.apache.org/mod_fcgid/)
      module
    * Nginx with the
      [fastcgi](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
      module
    * [Caddy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
    * Any other server that supports FastCGI

Fcgi.tcl comes with [automated tests](tests/) that use Nginx.  It has been
manually tested with Caddy.


## Installation

```sh
sudo make install
```

Be sure to add the directory you install Fcgi.tcl to to `auto_path` (for
example, through [`TCLLIBPATH`](https://wiki.tcl-lang.org/page/TCLLIBPATH)).


## Documentation

See the man page for Fcgi.tcl and the [NOTES](NOTES) file.  An HTML, text, and
PostScript version of the man page are in [doc/](doc/).  See also
[example/](example/).


## Known bugs

Fcgi.tcl has only been tested in the role of RESPONDER.  Other FastCGI roles
include AUTHORIZER and FILTER.  They have not been tested.
