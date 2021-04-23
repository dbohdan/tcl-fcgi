/if.*Tcl[X]*_Init.*interp.*==.*TCL_ERROR/{
n
n
n
i\
\
\ \ \ \ if (Fcgi_Init (interp) == TCL_ERROR) {\
\ \ \ \     return TCL_ERROR;\
\ \ \ \ }\
\ \ \ \ Tcl_StaticPackage (interp, "Fcgi", Fcgi_Init, (Tcl_PackageInitProc *) NULL);

}
