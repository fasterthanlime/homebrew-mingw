require 'formula'

class Sdl2Mixer < Formula
  homepage 'http://www.libsdl.org/projects/SDL_mixer/'
  head 'http://hg.libsdl.org/SDL_mixer', :using => :hg

  depends_on 'pkg-config' => :build
  depends_on 'sdl2'
  #depends_on 'flac' => :optional
  #depends_on 'libmikmod' => :optional
  depends_on 'libvorbis'

  def install
    inreplace 'SDL2_mixer.pc.in', '@prefix@', HOMEBREW_PREFIX

    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "CFLAGS=-I/usr/local/include",
                          "LDFLAGS=-L/usr/local/lib",
                          "WINDRES="
    system "make install"
  end
end

