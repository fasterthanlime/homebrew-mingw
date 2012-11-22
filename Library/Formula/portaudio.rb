require 'formula'

class Portaudio < Formula
  homepage 'http://www.portaudio.com'
  url 'http://www.portaudio.com/archives/pa_stable_v19_20111121.tgz'
  sha1 'f07716c470603729a55b70f5af68f4a6807097eb'

  depends_on 'pkg-config' => :build

  def install
    args = [ "--prefix=#{prefix}",
             "--disable-debug",
             "--disable-dependency-tracking" ]
    system "./configure", *args
    system "make install"
  end
end
