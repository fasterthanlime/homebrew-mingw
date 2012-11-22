require 'formula'

class Portaudio < Formula
  homepage 'http://www.portaudio.com'
  url 'http://www.portaudio.com/archives/pa_stable_v19_20111121.tgz'
  sha1 'f07716c470603729a55b70f5af68f4a6807097eb'

  depends_on 'pkg-config' => :build

  def patches
    DATA
  end

  def install
    args = [ "--prefix=#{prefix}",
             "--disable-debug",
             "--disable-dependency-tracking" ]
    system "./configure", *args
    system "make install"
  end
end

__END__
diff --git a/portaudio-2.0.pc.in b/portaudio-2.0.pc.in
index f5c1969..01763eb 100644
--- a/portaudio-2.0.pc.in
+++ b/portaudio-2.0.pc.in
@@ -8,5 +8,5 @@ Description: Portable audio I/O
 Requires:
 Version: 19

-Libs: -L${libdir} -lportaudio @LIBS@
+Libs: ${libdir}/libportaudio.lib @LIBS@
 Cflags: -I${includedir} @THREAD_CFLAGS@
