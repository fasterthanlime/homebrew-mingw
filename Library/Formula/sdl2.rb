require 'formula'

class Sdl2 < Formula
  homepage 'http://www.libsdl.org/'
  head 'http://hg.libsdl.org/SDL', :using => :hg

  if build.head?
    #depends_on :automake
    #depends_on :libtool
  end

  option :universal

  def install
    # we have to do this because most build scripts assume that all sdl modules
    # are installed to the same prefix. Consequently SDL stuff cannot be
    # keg-only but I doubt that will be needed.
    inreplace %w[sdl2.pc.in sdl2-config.in], '@prefix@', HOMEBREW_PREFIX

    ENV.universal_binary if build.universal?

    system "./autogen.sh" if build.head?

    args = %W[--prefix=#{prefix}]
    args << "--disable-nasm"
    args << '--without-x'

    system "./configure", *args
    system "make install"
  end

  def test
    system "#{bin}/sdl2-config", "--version"
  end
end
