require 'formula'

class Chipmunk < Formula
  homepage 'http://chipmunk-physics.net/'
  url 'http://chipmunk-physics.net/release/Chipmunk-6.x/Chipmunk-6.1.2.tgz'
  sha1 '9d9492150dd0ac03e96a6f0e4f316f36e873dfdf'

  head 'https://github.com/slembcke/Chipmunk-Physics.git'

  depends_on 'cmake' => :build

  def install
    system "cmake", "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                    "-DCMAKE_PREFIX_PATH=#{prefix}",
                    "-DPREFIX=#{prefix}",
                    "-G", "MSYS Makefiles",
                    "-DBUILD_DEMOS=OFF",
                    "."
    system "make install"
  end
end
