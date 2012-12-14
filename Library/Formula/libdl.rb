require 'formula'

class Libdl < Formula
  homepage ''
  url 'http://dlfcn-win32.googlecode.com/files/dlfcn-win32-r19.tar.bz2'
  version '19'
  sha1 'a0033e37a547c52059d0bf8664a96ecdeeb66419'

  def patches
    DATA
  end

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--libdir=#{prefix}/lib",
                          "--incdir=#{prefix}/include"
                        
    system "make"
    system "make install"
  end
end

__END__
diff --git a/configure b/configure
index 3ae2f88..92f93b9 100644
--- a/configure
+++ b/configure
@@ -190,3 +190,4 @@ enabled shared && {
     echo "msvc:   $msvc";
     echo "strip:  $stripping";
 }
+exit 0
