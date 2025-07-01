###############################################################################
#
# Fcgi.tcl-1.0
# Makefile for Fcgi.tcl
#
# Copyright 1998 Tom Poindexter

###############################################################################
#
# set the following defines as needed

PREFIX       ?= /usr/local

DATADIR      ?= $(PREFIX)/share/tcltk
MANDIR       ?= $(PREFIX)/share/man/man3
SCRIPTDIR    ?= $(DATADIR)/fcgi

TCLSH        ?= tclsh

#
# end of defines
#
###############################################################################


#------------------------------------------------------------------------------
# install targets

install: install-tcl-src

install-tcl-src: install-man
	mkdir -p $(SCRIPTDIR)
	cp tcl-src/fcgi.tcl $(SCRIPTDIR)
	cp tcl-src/fcgi-helpers.tcl $(SCRIPTDIR)
	cp tcl-src/pkgIndex.tcl $(SCRIPTDIR)

install-man: doc/fcgi.tcl.man
	mkdir -p $(MANDIR)
	gzip -9 < doc/fcgi.tcl.man > $(MANDIR)/fcgi.3tcl.gz

test:
	$(TCLSH) tests/fcgi-nginx.test

.PHONY: install install-man install-tcl-src test
###############################################################################
# end of Makefile
###############################################################################
