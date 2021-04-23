One patch against fcgibuf.c:
 
----[cut here]----------------------------------------------------------------
 
--- fcgibuf.c.old       Sun Jan 11 19:46:09 1998
+++ fcgibuf.c   Sun Jan 11 19:28:08 1998
@@ -9,6 +9,7 @@ 
 #include "fcgitcl.h"
 #include "fcgios.h" 
 #include "fcgibuf.h" 
+#include <assert.h>  
 
 /*
  *----------------------------------------------------------------------
  
----[cut here]----------------------------------------------------------------
 
And a patch against mod_fastcgi.c to mirror a change in the MD5 interface:
 
----[cut here]----------------------------------------------------------------
 
--- mod_fastcgi.c.old   Sun Jan 11 19:48:04 1998
+++ mod_fastcgi.c       Sun Jan 11 19:48:58 1998
@@ -117,11 +117,8 @@ 
 #include "http_log.h"
 #include "util_script.h"
 #include "http_conf_globals.h"
-#include "md5.h"
+#include "util_md5.h"
 
-/* Can't include "util_md5.h" here without compiler errors... */
-char *ap_md5(pool *a, unsigned char *string);
-
 #include "mod_fastcgi.h"
 #include "fastcgi.h"
 #include "fcgitcl.h"
@@ -1264,7 +1264,7 @@
     ASSERT(fcgiPool!=NULL);
     
     /* Hash the name - need to free memory on the SIGTERM */
-    return ((char *)ap_md5(fcgiPool,(unsigned char *)buffer));
+    return ((char *)md5(fcgiPool,(unsigned char *)buffer));
 }   
 #undef TMP_BUFSIZ
 
 
----[cut here]----------------------------------------------------------------
 

