require 'formula'

class Dropbear < Formula
  homepage ''
  url 'https://matt.ucc.asn.au/dropbear/dropbear-2012.55.tar.bz2'
  version '2012.55'
  sha1 '261d033c28031faa34b92390ad5278feb20c6efc'

  depends_on 'zlib'

  def install
    system "sh", "configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
    system "make install" # if this fails, try separate make/make install steps
  end
end
