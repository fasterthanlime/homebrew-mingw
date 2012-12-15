require 'formula'

class Zlib < Formula
  homepage ''
  url 'http://zlib.net/zlib-1.2.7.tar.gz'
  version '1.2.7'
  sha1 '4aa358a95d1e5774603e6fa149c926a80df43559'

  def install
    system "make -f win32/Makefile.gcc install INCLUDE_PATH=#{include} LIBRARY_PATH=#{lib} BINARY_PATH=#{bin}"
  end
end
