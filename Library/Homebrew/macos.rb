module MacOS extend self

  # This can be compared to numerics, strings, or symbols
  # using the standard Ruby Comparable methods.
  def version
    require 'version'
    MacOSVersion.new(MACOS_VERSION.to_s)
  end

  def cat
    if version == :mountain_lion then :mountainlion
    elsif version == :lion then :lion
    elsif version == :snow_leopard then :snowleopard
    elsif version == :leopard then :leopard
    else nil
    end
  end

  def locate tool
    # Don't call tools (cc, make, strip, etc.) directly!
    # Give the name of the binary you look for as a string to this method
    # in order to get the full path back as a Pathname.
    @locate ||= {}
    @locate[tool.to_s] ||= if File.executable? "/usr/bin/#{tool}"
      Pathname.new "/usr/bin/#{tool}"
    else
      # If the tool isn't in /usr/bin, then we first try to use xcrun to find
      # it. If it's not there, or xcode-select is misconfigured, we have to
      # look in dev_tools_path, and finally in xctoolchain_path, because the
      # tools were split over two locations beginning with Xcode 4.3+.
      xcrun_path = unless Xcode.bad_xcode_select_path?
        `/usr/bin/xcrun -find #{tool} 2>/dev/null`.chomp
      end

      paths = %W[#{xcrun_path}
                 #{dev_tools_path}/#{tool}
                 #{xctoolchain_path}/usr/bin/#{tool}]
      paths.map { |p| Pathname.new(p) }.find { |p| p.executable? }
    end
  end

  def dev_tools_path
    @dev_tools_path ||= Pathname.new "/usr/bin"
  end

  def xctoolchain_path
    # As of Xcode 4.3, some tools are located in the "xctoolchain" directory
    @xctoolchain_path ||= begin
      path = Pathname.new("#{Xcode.prefix}/Toolchains/XcodeDefault.xctoolchain")
      # If only the CLT are installed, all tools will be under dev_tools_path,
      # this path won't exist, and xctoolchain_path will be nil.
      path if path.exist?
    end
  end

  def sdk_path(v = version)
    @sdk_path ||= {}
    @sdk_path[v.to_s] ||= begin
      opts = []
      # First query Xcode itself
      opts << `#{locate('xcodebuild')} -version -sdk macosx#{v} Path 2>/dev/null`.chomp unless Xcode.bad_xcode_select_path?
      # Xcode.prefix is pretty smart, so lets look inside to find the sdk
      opts << "#{Xcode.prefix}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX#{v}.sdk"
      # Xcode < 4.3 style
      opts << "/Developer/SDKs/MacOSX#{v}.sdk"
      opts.map{|a| Pathname.new(a) }.detect { |p| p.directory? }
    end
  end

  def default_cc
    cc = locate 'cc'
    Pathname.new(cc).realpath.basename.to_s rescue nil
  end

  def default_compiler
    case default_cc
      when /^gcc/ then :gcc
      when /^llvm/ then :llvm
      when "clang" then :clang
      else
        # guess :(
        if Xcode.version >= "4.3"
          :clang
        elsif Xcode.version >= "4.2"
          :llvm
        else
          :gcc
        end
    end
  end

  def gcc_40_build_version
    @gcc_40_build_version ||= if locate("gcc-4.0")
      `#{locate("gcc-4.0")} --version` =~ /build (\d{4,})/
      $1.to_i
    end
  end

  def gcc_42_build_version
    @gcc_42_build_version ||= if locate("gcc-4.2") \
      and not locate("gcc-4.2").realpath.basename.to_s =~ /^llvm/
      `#{locate("gcc-4.2")} --version` =~ /build (\d{4,})/
      $1.to_i
    end
  end

  def llvm_build_version
    # for Xcode 3 on OS X 10.5 this will not exist
    # NOTE may not be true anymore but we can't test
    @llvm_build_version ||= if locate("llvm-gcc")
      `#{locate("llvm-gcc")} --version` =~ /LLVM build (\d{4,})/
      $1.to_i
    end
  end

  def clang_version
    @clang_version ||= if locate("clang")
      `#{locate("clang")} --version` =~ /clang version (\d\.\d)/
      $1
    end
  end

  def clang_build_version
    @clang_build_version ||= if locate("clang")
      `#{locate("clang")} --version` =~ %r[tags/Apple/clang-(\d{2,})]
      $1.to_i
    end
  end

  def macports_or_fink_installed?
    # See these issues for some history:
    # http://github.com/mxcl/homebrew/issues/#issue/13
    # http://github.com/mxcl/homebrew/issues/#issue/41
    # http://github.com/mxcl/homebrew/issues/#issue/48
    return false unless MACOS

    %w[port fink].each do |ponk|
      path = which(ponk)
      return ponk unless path.nil?
    end

    # we do the above check because macports can be relocated and fink may be
    # able to be relocated in the future. This following check is because if
    # fink and macports are not in the PATH but are still installed it can
    # *still* break the build -- because some build scripts hardcode these paths:
    %w[/sw/bin/fink /opt/local/bin/port].each do |ponk|
      return ponk if File.exist? ponk
    end

    # finally, sometimes people make their MacPorts or Fink read-only so they
    # can quickly test Homebrew out, but still in theory obey the README's
    # advise to rename the root directory. This doesn't work, many build scripts
    # error out when they try to read from these now unreadable directories.
    %w[/sw /opt/local].each do |path|
      path = Pathname.new(path)
      return path if path.exist? and not path.readable?
    end

    false
  end

  def prefer_64_bit?
    Hardware.is_64_bit? and version != :leopard
  end

  STANDARD_COMPILERS = {
    "3.1.4" => { :gcc_40_build => 5493, :gcc_42_build => 5577 },
    "3.2.6" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "1.7", :clang_build => 77 },
    "4.0"   => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
    "4.0.1" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
    "4.0.2" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
    "4.2"   => { :llvm_build => 2336, :clang => "3.0", :clang_build => 211 },
    "4.3"   => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
    "4.3.1" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
    "4.3.2" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
    "4.3.3" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
    "4.4"   => { :llvm_build => 2336, :clang => "4.0", :clang_build => 421 },
    "4.4.1" => { :llvm_build => 2336, :clang => "4.0", :clang_build => 421 },
    "4.5"   => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
    "4.5.1" => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
    "4.5.2" => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 }
  }

  def compilers_standard?
    xcode = Xcode.version

    unless STANDARD_COMPILERS.keys.include? xcode
      onoe <<-EOS.undent
        Homebrew doesn't know what compiler versions ship with your version of
        Xcode. Please `brew update` and if that doesn't help, file an issue with
        the output of `brew --config`:
          https://github.com/mxcl/homebrew/issues

        Thanks!
        EOS
      return
    end

    STANDARD_COMPILERS[xcode].all? do |method, build|
      MacOS.send(:"#{method}_version") == build
    end
  end

  def app_with_bundle_id id
    path = mdfind(id).first
    Pathname.new(path) unless path.nil? or path.empty?
  end

  def mdfind id
    `/usr/bin/mdfind "kMDItemCFBundleIdentifier == '#{id}'"`.split("\n")
  end

  def pkgutil_info id
    `/usr/sbin/pkgutil --pkg-info "#{id}" 2>/dev/null`.strip
  end

  def bottles_supported?
    # We support bottles on all versions of OS X except 32-bit Snow Leopard.
    (Hardware.is_64_bit? or not MacOS.version >= :snow_leopard) \
      and HOMEBREW_PREFIX.to_s == '/usr/local' \
      and HOMEBREW_CELLAR.to_s == '/usr/local/Cellar' \
  end
end

require 'macos/xcode'
require 'macos/xquartz'
