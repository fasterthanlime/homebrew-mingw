require 'formula'

class SdlMixer < Formula
  homepage 'http://www.libsdl.org/projects/SDL_mixer/'
  url 'http://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.12.zip'
  sha1 '127a8bf494f18fb628aec0285ac97d447000c34c'

  depends_on 'pkg-config' => :build
  depends_on 'sdl'
  #depends_on 'flac' => :optional
  #depends_on 'libmikmod' => :optional
  depends_on 'libvorbis' => :optional

  def install
    inreplace 'SDL_mixer.pc.in', '@prefix@', HOMEBREW_PREFIX

    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking"
    system "make install"
  end
end
