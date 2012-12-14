require 'formula'

class Czmq < Formula
  homepage 'http://czmq.zeromq.org/'
  url 'http://download.zeromq.org/czmq-1.3.1.tar.gz'
  sha1 '73dea800cf556d66d5a4630bb7f99bd313cc30dc'

  head 'https://github.com/zeromq/czmq.git'

  option :universal

  depends_on 'zeromq'

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}", "--with-libzmq=#{HOMEBREW_PREFIX}"
    system "make install"
  end

  def patches
    # Don't redefine int32_t on mingw (fixed in HEAD, not in 1.3.1)
    DATA
  end
end

__END__
diff --git a/include/czmq_prelude.h b/include/czmq_prelude.h
index 720797f..5440387 100644
--- a/include/czmq_prelude.h
+++ b/include/czmq_prelude.h
@@ -399,11 +399,13 @@ typedef unsigned int    qbyte;          //  Quad byte = 32 bits
 #   define vsnprintf _vsnprintf
     typedef unsigned long ulong;
     typedef unsigned int  uint;
+#   if (!defined(__MINGW32__))
     typedef __int32 int32_t;
     typedef __int64 int64_t;
     typedef unsigned __int32 uint32_t;
     typedef unsigned __int64 uint64_t;
     typedef long ssize_t;
+#   endif
 #elif (defined (__APPLE__))
     typedef unsigned long ulong;
     typedef unsigned int uint;
