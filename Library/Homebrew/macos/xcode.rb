module MacOS::Xcode extend self

  V4_BUNDLE_ID = "com.apple.dt.Xcode"
  V3_BUNDLE_ID = "com.apple.Xcode"
  V4_BUNDLE_PATH = Pathname.new("/Applications/Xcode.app")
  V3_BUNDLE_PATH = Pathname.new("/Developer/Applications/Xcode.app")

  # Locate the "current Xcode folder" via xcode-select. See:
  # man xcode-select
  # NOTE!! use Xcode.prefix rather than this generally!
  def folder
    @folder ||= `xcode-select -print-path 2>/dev/null`.strip
  end

  # Xcode 4.3 tools hang if "/" is set
  def bad_xcode_select_path?
    folder == "/"
  end

  def latest_version
    case MacOS.version
      when 10.5 then "3.1.4"
      when 10.6 then "3.2.6"
    else
      if MacOS.version >= 10.7
        "4.5.2"
      else
        raise "Mac OS X `#{MacOS.version}' is invalid"
      end
    end
  end

  def prefix
    @prefix ||= begin
      path = Pathname.new(folder)
      if path.absolute? and (path/'usr/bin/make').executable?
        path
      end
    end
  end

  def installed?
    true
  end

  def version
    ## Hacky, we shouldn't need XCode at all
    return "4.5"
  end

  def provides_autotools?
    version.to_f < 4.3
  end

  def provides_gcc?
    version.to_f < 4.3
  end
end

module MacOS::CLT extend self
  STANDALONE_PKG_ID = "com.apple.pkg.DeveloperToolsCLILeo"
  FROM_XCODE_PKG_ID = "com.apple.pkg.DeveloperToolsCLI"

  # This is true if the standard UNIX tools are present under /usr. For
  # Xcode < 4.3, this is the standard location. Otherwise, it means that
  # the user has installed the "Command Line Tools for Xcode" package.
  def installed?
    MacOS.dev_tools_path == Pathname.new("/usr/bin")
  end

  def latest_version?
    `/usr/bin/clang -v 2>&1` =~ %r{tags/Apple/clang-(\d+)\.(\d+)\.(\d+)}
    $1.to_i >= 421 and $3.to_i >= 57
  end

  def version
    # The pkgutils calls are slow, don't repeat if no CLT installed.
    return @version if @version_determined

    @version_determined = true
    # Version string (a pretty damn long one) of the CLT package.
    # Note, that different ways to install the CLTs lead to different
    # version numbers.
    @version ||= [STANDALONE_PKG_ID, FROM_XCODE_PKG_ID].find do |id|
      MacOS.pkgutil_info(id) =~ /version: (.+)$/
    end && $1
  end
end
