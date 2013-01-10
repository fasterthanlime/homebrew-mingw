require 'formula'

class Sdl2Image < Formula
  homepage 'http://www.libsdl.org/projects/SDL_image'
  head 'http://hg.libsdl.org/SDL_image', :using => :hg

  depends_on 'sdl2'

  option :universal

  def install
    ENV.universal_binary if build.universal?

    system "sh", "autogen.sh" if build.head?

    inreplace 'SDL2_image.pc.in', '@prefix@', HOMEBREW_PREFIX

    system "sh", "configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "--disable-sdltest",
                          "CFLAGS=-I#{HOMEBREW_PREFIX}/include -L#{HOMEBREW_PREFIX}/lib"
    system "make install"
  end
end
