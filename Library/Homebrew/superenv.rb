require 'extend/ENV'
require 'macos'

### Why `superenv`?
# 1) Only specify the environment we need (NO LDFLAGS for cmake)
# 2) Only apply compiler specific options when we are calling that compiler
# 3) Force all incpaths and libpaths into the cc instantiation (less bugs)
# 4) Cater toolchain usage to specific Xcode versions
# 5) Remove flags that we don't want or that will break builds
# 6) Simpler code
# 7) Simpler formula that *just work*
# 8) Build-system agnostic configuration of the tool-chain

def superbin
  @bin ||= (HOMEBREW_REPOSITORY/"Library/ENV").children.max
end

def superenv?
  superbin and superbin.directory? and
  not ARGV.include? "--env=std"
end

class << ENV
  attr :deps, true
  attr :all_deps, true # above is just keg-only-deps
  attr :x11, true
  alias_method :x11?, :x11

  def reset
    %w{CC CXX OBJC OBJCXX CPP MAKE LD
      CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS LDFLAGS CPPFLAGS
      MACOS_DEPLOYMENT_TARGET SDKROOT
      CMAKE_PREFIX_PATH CMAKE_INCLUDE_PATH CMAKE_FRAMEWORK_PATH}.
      each{ |x| delete(x) }
    delete('CDPATH') # avoid make issues that depend on changing directories
    delete('GREP_OPTIONS') # can break CMake
    delete('CLICOLOR_FORCE') # autotools doesn't like this
  end

  def setup_build_environment
    reset
    check
    ENV['CC'] = 'cc'
    ENV['CXX'] = 'c++'
    ENV['OBJC'] = 'cc'
    ENV['OBJCXX'] = 'c++'
    ENV['DEVELOPER_DIR'] = determine_developer_dir # effects later settings
    ENV['MAKEFLAGS'] ||= "-j#{determine_make_jobs}"
    ENV['PATH'] = determine_path
    ENV['PKG_CONFIG_PATH'] = determine_pkg_config_path
    ENV['HOMEBREW_CC'] = determine_cc
    ENV['HOMEBREW_CCCFG'] = determine_cccfg
    ENV['CMAKE_PREFIX_PATH'] = determine_cmake_prefix_path
    ENV['CMAKE_INCLUDE_PATH'] = determine_cmake_include_path
    ENV['CMAKE_LIBRARY_PATH'] = determine_cmake_library_path
    ENV['ACLOCAL_PATH'] = determine_aclocal_path
  end

  def check
    # TODO: actual sanity checks
  end

  def universal_binary
    # Irrelevant on Windows
  end

  private

  def determine_cc
    if ARGV.include? '--use-gcc'
      "gcc"
    elsif ARGV.include? '--use-llvm'
      "llvm-gcc"
    elsif ARGV.include? '--use-clang'
      "clang"
    elsif ENV['HOMEBREW_USE_CLANG']
      opoo %{HOMEBREW_USE_CLANG is deprecated, use HOMEBREW_CC="clang" instead}
      "clang"
    elsif ENV['HOMEBREW_USE_LLVM']
      opoo %{HOMEBREW_USE_LLVM is deprecated, use HOMEBREW_CC="llvm" instead}
      "llvm-gcc"
    elsif ENV['HOMEBREW_USE_GCC']
      opoo %{HOMEBREW_USE_GCC is deprecated, use HOMEBREW_CC="gcc" instead}
      "gcc"
    elsif ENV['HOMEBREW_CC']
      case ENV['HOMEBREW_CC']
        when 'clang', 'gcc' then ENV['HOMEBREW_CC']
        when 'llvm', 'llvm-gcc' then 'llvm-gcc'
      else
        opoo "Invalid value for HOMEBREW_CC: #{ENV['HOMEBREW_CC']}"
        raise # use default
      end
    else
      raise
    end
  rescue
    "clang"
  end

  def determine_path
    paths = [superbin]
    paths += all_deps.map{|dep| "#{HOMEBREW_PREFIX}/opt/#{dep}/bin" }
    paths += %w{C:/MinGW/msys/1.0/bin}
    paths.to_path_s
  end

  def determine_pkg_config_path
    paths  = deps.map{|dep| "#{HOMEBREW_PREFIX}/opt/#{dep}/lib/pkgconfig" }
    paths += deps.map{|dep| "#{HOMEBREW_PREFIX}/opt/#{dep}/share/pkgconfig" }
    paths << "#{HOMEBREW_PREFIX}/lib/pkgconfig"
    paths << "#{HOMEBREW_PREFIX}/share/pkgconfig"
    # Mountain Lion no longer ships some .pcs; ensure we pick up our versions
    paths << "#{HOMEBREW_REPOSITORY}/Library/ENV/pkgconfig/mountain_lion" if MacOS.version >= :mountain_lion
    paths.to_path_s
  end

  def determine_cmake_prefix_path
    paths = deps.map{|dep| "#{HOMEBREW_PREFIX}/opt/#{dep}" }
    paths << HOMEBREW_PREFIX.to_s # put ourselves ahead of everything else
    paths.to_path_s
  end

  def determine_cmake_include_path
    paths = []
    paths.to_path_s
  end

  def determine_cmake_library_path
    paths = []
    # things expect to find GL headers since X11 used to be a default, so we add them
    paths.to_path_s
  end

  def determine_aclocal_path
    paths = deps.map{|dep| "#{HOMEBREW_PREFIX}/opt/#{dep}/share/aclocal" }
    paths << "#{HOMEBREW_PREFIX}/share/aclocal"
    paths << "/opt/X11/share/aclocal" if x11?
    paths.to_path_s
  end

  def determine_make_jobs
    if (j = ENV['HOMEBREW_MAKE_JOBS'].to_i) < 1
      Hardware.processor_count
    else
      j
    end
  end

  def determine_cccfg
    s = ""
    s << 'b' if ARGV.build_bottle?
    # Fix issue with sed barfing on unicode characters on Mountain Lion
    s << 's' if MacOS.version >= :mountain_lion
    # Fix issue with 10.8 apr-1-config having broken paths
    s << 'a' if MacOS.version == :mountain_lion
    s
  end

  def determine_developer_dir
    # If Xcode path is fucked then this is basically a fix. In the case where
    # nothing is valid, it still fixes most usage to supply a valid path that
    # is not "/".
    if MacOS::Xcode.bad_xcode_select_path?
      (MacOS::Xcode.prefix || HOMEBREW_PREFIX).to_s
    elsif ENV['DEVELOPER_DIR']
      ENV['DEVELOPER_DIR']
    end
  end

  def brewed_python?
    require 'formula'
    Formula.factory('python').linked_keg.directory?
  end

  public

### NO LONGER NECESSARY OR NO LONGER SUPPORTED
  def noop(*args); end
  %w[m64 m32 gcc_4_0_1 fast O4 O3 O2 Os Og O1 libxml2 minimal_optimization
    no_optimization enable_warnings x11
    set_cpu_flags
    macosxsdk remove_macosxsdk].each{|s| alias_method s, :noop }

### DEPRECATE THESE
  def compiler
    case ENV['HOMEBREW_CC']
      when "llvm-gcc" then :llvm
      when "gcc", "clang" then ENV['HOMEBREW_CC'].to_sym
    else
      raise
    end
  end
  def deparallelize
    delete('MAKEFLAGS')
  end
  alias_method :j1, :deparallelize
  def gcc
    ENV['CC'] = ENV['OBJC'] = ENV['HOMEBREW_CC'] = "gcc"
    ENV['CXX'] = ENV['OBJCXX'] = "g++"
  end
  def llvm
    ENV['CC'] = ENV['OBJC'] = ENV['HOMEBREW_CC'] = "llvm-gcc"
    ENV['CXX'] = ENV['OBJCXX'] = "g++"
  end
  def clang
    ENV['CC'] = ENV['OBJC'] = ENV['HOMEBREW_CC'] = "clang"
    ENV['CXX'] = ENV['OBJCXX'] = "clang++"
  end
  def make_jobs
    ENV['MAKEFLAGS'] =~ /-\w*j(\d)+/
    [$1.to_i, 1].max
  end

  # Many formula assume that CFLAGS etc. will not be nil.
  # This should be a safe hack to prevent that exception cropping up.
  # Main consqeuence of this is that ENV['CFLAGS'] is never nil even when it
  # is which can break if checks, but we don't do such a check in our code.
  def [] key
    if has_key? key
      fetch(key)
    elsif %w{CPPFLAGS CFLAGS LDFLAGS}.include? key
      class << (a = "")
        attr :key, true
        def + value
          ENV[key] = value
        end
        alias_method '<<', '+'
      end
      a.key = key
      a
    end
  end

end if superenv?


if not superenv?
  ENV.extend(HomebrewEnvExtension)
  # we must do this or tools like pkg-config won't get found by configure scripts etc.
  ENV.prepend 'PATH', "#{HOMEBREW_PREFIX}/bin", ':' unless ORIGINAL_PATHS.include? HOMEBREW_PREFIX/'bin'
else
  ENV.deps = []
  ENV.all_deps = []
end


class Array
  def to_path_s
    puts "Original paths = #{self}"
    result = map(&:to_s).uniq.select{|s| File.directory? s }.join(';').chuzzle
    puts "result = #{result}"
    result
  end
end

