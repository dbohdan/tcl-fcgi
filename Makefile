###############################################################################
#
# Fcgi.tcl-1.0
# Makefile for Fcgi.tcl
#
# Copyright 1998 Tom Poindexter

###############################################################################
#
# set the following defines as needed

PREFIX       = /usr/local

DATADIR      = $(PREFIX)/share/tcltk
MANDIR       = $(PREFIX)/man/man3
SCRIPTDIR    = $(DATADIR)/fcgi

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
	gzip -9 < $< > $(MANDIR)/fcgi.3tcl.gz

###############################################################################
# end of Makefile
###############################################################################
