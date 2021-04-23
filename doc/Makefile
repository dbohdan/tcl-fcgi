all:
	rman -f html    fcgi.tcl.man  >fcgi.tcl.html
	nroff -man      fcgi.tcl.man  >fcgi.tcl.txt
	groff -Tps -man fcgi.tcl.man  >fcgi.tcl.ps
