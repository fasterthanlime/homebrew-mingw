require 'formula'

class Curl < Formula
  homepage 'http://curl.haxx.se/'
  url 'http://curl.haxx.se/download/curl-7.28.0.tar.gz'
  sha256 'ececf0355d352925cb41936be6b50b68d8af1fbd737e267c8fe9e929c5539ff4'

  option 'with-ssh', 'Build with scp and sftp support'
  option 'with-libmetalink', 'Build with Metalink support'

  depends_on 'pkg-config' => :build
  depends_on 'libssh2' if build.include? 'with-ssh'
  depends_on 'libmetalink' if build.include? 'with-libmetalink'

  def install
    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --prefix=#{prefix}
      --cache-file=/dev/null
      --disable-shared
      --host=i686-pc-mingw32
      --disable-option-checking
      host_alias=i686-pc-mingw32
    ]

    args << "--with-libssh2" if build.include? 'with-ssh'
    args << "--with-libmetalink" if build.include? 'with-libmetalink'

    system "sh", "configure", *args
    system "make install"
  end
end
