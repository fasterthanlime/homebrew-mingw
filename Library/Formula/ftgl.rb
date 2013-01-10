require 'formula'

class Ftgl < Formula
  url 'http://downloads.sourceforge.net/project/ftgl/FTGL%20Source/2.1.3~rc5/ftgl-2.1.3-rc5.tar.gz'
  homepage 'http://sourceforge.net/projects/ftgl/'
  sha1 'b9c11d3a594896333f1bbe46e10d8617713b4fc6'

  depends_on :freetype

  def patches
    DATA
  end

  def install
    # If doxygen is installed, the docs may still fail to build.
    # So we disable building docs.
    inreplace "configure", "set dummy doxygen;", "set dummy no_doxygen;"

    ENV["PATH"] = "#{ENV["PATH"]};C:/MinGW/msys/1.0/local/bin"

    system "./autogen.sh"
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--disable-freetypetest"

    # Hack the package info
    inreplace "ftgl.pc", "Requires.private: freetype2\n", ""

    system "make install"
  end
end

__END__
diff --git a/Makefile.am b/Makefile.am
index 89a8a7f..aabd9fd 100644
--- a/Makefile.am
+++ b/Makefile.am
@@ -1,4 +1,6 @@
 
+ECHO=echo
+
 ACLOCAL_AMFLAGS = -I m4
 
 SUBDIRS = src test demo docs
diff --git a/m4/gl.m4 b/m4/gl.m4
index ed583ac..9374dff 100644
--- a/m4/gl.m4
+++ b/m4/gl.m4
@@ -63,6 +63,8 @@ else
     LIBS="-lGL"
 fi
 AC_LINK_IFELSE([AC_LANG_CALL([],[glBegin])],[HAVE_GL=yes], [HAVE_GL=no])
+HAVE_GL=yes
+LIBS="-lopengl32"
 if test "x$HAVE_GL" = xno ; then
     if test "x$GL_X_LIBS" != x ; then
         LIBS="-lGL $GL_X_LIBS"
@@ -105,6 +107,8 @@ if test "x$FRAMEWORK_OPENGL" = "x" ; then
 AC_MSG_CHECKING([for GLU library])
 LIBS="-lGLU $GL_LIBS"
 AC_LINK_IFELSE([AC_LANG_CALL([],[gluNewTess])],[HAVE_GLU=yes], [HAVE_GLU=no])
+LIBS="-lglu32 $GL_LIBS"
+HAVE_GLU=yes
 if test "x$HAVE_GLU" = xno ; then
     if test "x$GL_X_LIBS" != x ; then
         LIBS="-lGLU $GL_LIBS $GL_X_LIBS"
