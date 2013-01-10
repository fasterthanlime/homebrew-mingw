require 'formula'

class Libpng < Formula
  homepage 'http://www.libpng.org/pub/png/libpng.html'
  url 'http://downloads.sf.net/project/libpng/libpng15/1.5.13/libpng-1.5.13.tar.gz'
  sha1 '43a86bc5ba927618fd6c440bc4fd770d87d06b80'

  depends_on 'zlib'

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "CFLAGS=-I#{HOMEBREW_PREFIX}/include -L#{HOMEBREW_PREFIX}/lib"
    system "make install"
  end
end
