require 'formula'

class Ftgl < Formula
  url 'http://downloads.sourceforge.net/project/ftgl/FTGL%20Source/2.1.3~rc5/ftgl-2.1.3-rc5.tar.gz'
  homepage 'http://sourceforge.net/projects/ftgl/'
  sha1 'b9c11d3a594896333f1bbe46e10d8617713b4fc6'

  depends_on :freetype

  def install
    # If doxygen is installed, the docs may still fail to build.
    # So we disable building docs.
    inreplace "configure", "set dummy doxygen;", "set dummy no_doxygen;"

    system "sh", "configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--disable-freetypetest",
    # Skip building the example program by failing to find GLUT (MacPorts)
                          "--with-glut-inc=/dev/null",
                          "--with-glut-lib=/dev/null"

    # Hack the package info
    inreplace "ftgl.pc", "Requires.private: freetype2\n", ""

    system "make install"
  end
end
