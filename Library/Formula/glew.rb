require 'formula'

class Glew < Formula
  homepage 'http://glew.sourceforge.net/'
  url 'http://downloads.sourceforge.net/project/glew/glew/1.9.0/glew-1.9.0.tgz'
  sha1 '9291f5c5afefd482c7f3e91ffb3cd4716c6c9ffe'

  def patches
    DATA
  end

  def install
    system "make", "GLEW_DEST=#{prefix}", "all"
    system "make", "GLEW_DEST=#{prefix}", "install.all"
  end
end

__END__
diff --git a/Makefile b/Makefile
index 77d693d..48a98bb 100644
--- a/Makefile
+++ b/Makefile
@@ -131,7 +131,7 @@ glew.pc: glew.pc.in
 		-e "s|@includedir@|$(INCDIR)|g" \
 		-e "s|@version@|$(GLEW_VERSION)|g" \
 		-e "s|@cflags@||g" \
-		-e "s|@libname@|GLEW|g" \
+		-e "s|@libname@|glew32|g" \
 		< $< > $@
 
 # GLEW MX static and shared libraries
