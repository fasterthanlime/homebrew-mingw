require 'formula'

class Cubeb < Formula
  homepage 'https://github.com/kinetiknz/cubeb'

  head 'https://github.com/kinetiknz/cubeb.git'

  depends_on 'pkg-config' => :build

  def install
    ENV.universal_binary if build.universal?

    system "autoreconf --install" if build.head?

    args = %W[--prefix=#{prefix}]
    system './configure', *args
    system "make install"
  end

end

