require 'formula'

class FreeimageHttpDownloadStrategy < CurlDownloadStrategy
  def stage
    # need to convert newlines or patch chokes
    safe_system 'unzip', '-aaqq', @tarball_path
    chdir
  end
end

class Freeimage < Formula
  homepage 'http://sf.net/projects/freeimage'
  url 'http://downloads.sourceforge.net/project/freeimage/Source%20Distribution/3.15.3/FreeImage3153.zip',
        :using => FreeimageHttpDownloadStrategy
  version '3.15.3'
  sha1 '083ef40a1734e33cc34c55ba87019bf5cce9ca4a'

  option :universal

  def patches
    DATA
  end

  def install
    system "make", "-f", "Makefile.mingw"
    system "make", "-f", "Makefile.mingw", "install", "PREFIX=#{prefix}", "INCDIR=#{include}", "INSTALLDIR=#{lib}"
  end
end

__END__
diff --git a/Makefile.mingw b/Makefile.mingw
index 7b27892..6218ab3 100644
--- a/Makefile.mingw
+++ b/Makefile.mingw
@@ -4,8 +4,8 @@
 include Makefile.srcs
 
 # General configuration variables:
-DESTDIR ?= $(SystemRoot)
-INSTALLDIR ?= $(DESTDIR)/system32
+INCDIR ?= $(PREFIX)/include/
+INSTALLDIR ?= $(PREFIX)/lib/
 DISTDIR ?= Dist
 SRCDIR ?= Source
 HEADER = FreeImage.h
@@ -37,14 +37,26 @@ CP = cp
 # Define the mkdir command
 MD = mkdir
 
-# Define additional libraries needed:
+# Define the rm command
+RM = rm
+
+# Define additional libraries needed.
 # libstdc++ is included by default with MinGW, however for
 # WIN32 based builds, LibRawLite needs the winsock libraries.
 LIBRARIES = -lwsock32 -lws2_32
 
-# Define some additional symboles only needed for WIN32 based builds:
-WIN32_CFLAGS = $(LIB_TYPE_FLAGS) -DOPJ_STATIC
-WIN32_CXXFLAGS = $(WIN32_CFLAGS) -DLIBRAW_NODLL -DLIBRAW_LIBRARY_BUILD
+# Define some additional symboles needed for WIN32 based builds.
+WIN32_CFLAGS = -DWINVER=0x0500 $(LIB_TYPE_FLAGS) -DOPJ_STATIC
+WIN32_CXXFLAGS = $(WIN32_CFLAGS) -DLIBRAW_NODLL
+
+# Workaround for LibRawLite, which does not include C++ header
+# file stdexcept, which is casually included with MSVC but not
+# with MinGW. This can be removed after LibRawLite got control
+# over its includes again.
+WIN32_CXXFLAGS += -include stdexcept 
+
+# Define DLL image header information flags for the linker.
+WIN32_LDFLAGS = -Wl,--subsystem,windows:5.0,--major-os-version,5 -lws2_32
 
 WIN32_STATIC_FLAGS = -DFREEIMAGE_LIB
 WIN32_SHARED_FLAGS = -DFREEIMAGE_EXPORTS
@@ -54,14 +66,14 @@ MODULES := $(MODULES:.cpp=.o)
 RESOURCE = $(RCFILE:.rc=.coff)
 CFLAGS ?= -O3 -fexceptions -DNDEBUG $(WIN32_CFLAGS)
 CFLAGS += $(INCLUDE)
-CXXFLAGS ?= -O3 -fexceptions -Wno-ctor-dtor-privacy -DNDEBUG $(WIN32_CXXFLAGS) -DNO_LCMS
+CXXFLAGS ?= -O3 -fexceptions -Wno-ctor-dtor-privacy -DNDEBUG $(WIN32_CXXFLAGS)
 CXXFLAGS += $(INCLUDE)
 RCFLAGS ?= -DNDEBUG
-LDFLAGS = -s -shared -static -Wl,-soname,$(SOLIBNAME)
-DLLTOOLFLAGS = --add-stdcall-underscore
+LDFLAGS ?= -s -shared -static -Wl,-soname,$(SOLIBNAME) $(WIN32_LDFLAGS)
+DLLTOOLFLAGS ?= --add-stdcall-underscore
 
 TARGET = FreeImage
-STATICLIB = $(TARGET).a
+STATICLIB = lib$(TARGET).a
 SHAREDLIB = $(TARGET).dll
 IMPORTLIB = $(TARGET).lib
 EXPORTLIB = $(TARGET).exp
@@ -70,7 +82,7 @@ SOLIBNAME = $(SHAREDLIB).$(VER_MAJOR)
 DISTSHARED = $(addprefix $(DISTDIR)/, $(SHAREDLIB) $(IMPORTLIB) $(HEADER))
 DISTSTATIC = $(addprefix $(DISTDIR)/, $(STATICLIB) $(HEADER))
 
-# The FreeImage library type defaults to SHARED
+# The FreeImage library type defaults to SHARED.
 FREEIMAGE_LIBRARY_TYPE ?= SHARED
 
 TARGETLIB = $($(FREEIMAGE_LIBRARY_TYPE)LIB)
@@ -117,7 +129,11 @@ $(DISTDIR):
 $(TARGETDIST): $(DISTDIR)
 
 install:
+	$(MD) $(INSTALLDIR)
 	$(CP) $(SHAREDLIB) $(INSTALLDIR)
+	$(CP) $(IMPORTLIB) $(INSTALLDIR)
+	$(MD) $(INCDIR)
+	$(CP) $(SRCDIR)/$(HEADER) $(INCDIR)
 
 clean:
-	$(RM) core $(DISTDIR)/*.* $(MODULES) $(RESOURCE) $(STATICLIB) $(SHAREDLIB) $(IMPORTLIB) $(EXPORTLIB)
+	$(RM) -f core $(DISTDIR)/*.* $(MODULES) $(RESOURCE) $(STATICLIB) $(SHAREDLIB) $(IMPORTLIB) $(EXPORTLIB)
