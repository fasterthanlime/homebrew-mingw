require 'formula'

class Libyaml < Formula
  homepage 'http://pyyaml.org/wiki/LibYAML'
  url 'http://pyyaml.org/download/libyaml/yaml-0.1.4.tar.gz'
  sha1 'e0e5e09192ab10a607e3da2970db492118f560f2'

  def patches
    DATA
  end

  def install
    args = ["--prefix=#{prefix}"]

    if build.universal?
      ENV['CFLAGS'] = "-arch i386 -arch x86_64"
      ENV['LDFLAGS'] = "-arch i386 -arch x86_64"
      args << "--disable-dependency-tracking"
    end

    system './configure', *args
    system "make install"
  end
end

__END__
diff --git a/include/yaml.h b/include/yaml.h
index 5a04d36..9b9d9a4 100644
--- a/include/yaml.h
+++ b/include/yaml.h
@@ -26,7 +26,9 @@ extern "C" {

 /** The public API declaration. */

-#ifdef _WIN32
+#if defined(__MINGW32__)
+#   define YAML_DECLARE(type) type
+#elif defined(_WIN32)
 #   if defined(YAML_DECLARE_STATIC)
 #       define  YAML_DECLARE(type)  type
 #   elif defined(YAML_DECLARE_EXPORT)
diff --git a/yaml-0.1.pc.in b/yaml-0.1.pc.in
index c566abf..70c8008 100644
--- a/yaml-0.1.pc.in
+++ b/yaml-0.1.pc.in
@@ -6,5 +6,5 @@ libdir=@libdir@
 Name: LibYAML
 Description: Library to parse and emit YAML
 Version: @PACKAGE_VERSION@
-Cflags:
+Cflags: -I${includedir}
 Libs: -L${libdir} -lyaml
