require 'exceptions'
require 'formula'
require 'keg'
require 'tab'
require 'bottles'

class FormulaInstaller
  attr :f
  attr :tab
  attr :show_summary_heading, true
  attr :ignore_deps, true
  attr :install_bottle, true
  attr :show_header, true

  def initialize ff, tab=nil
    @f = ff
    @tab = tab
    @show_header = false
    @ignore_deps = ARGV.ignore_deps? || ARGV.interactive?
    @install_bottle = install_bottle? ff

    check_install_sanity
  end

  def check_install_sanity
    if f.installed?
      msg = "#{f}-#{f.installed_version} already installed"
      msg << ", it's just not linked" if not f.linked_keg.symlink? and not f.keg_only?
      raise CannotInstallFormulaError, msg
    end

    # Building head-only without --HEAD is an error
    if not ARGV.build_head? and f.stable.nil?
      raise CannotInstallFormulaError, <<-EOS.undent
        #{f} is a head-only formula
        Install with `brew install --HEAD #{f.name}
      EOS
    end

    # Building stable-only with --HEAD is an error
    if ARGV.build_head? and f.head.nil?
      raise CannotInstallFormulaError, "No head is defined for #{f.name}"
    end

    unless ignore_deps
      unlinked_deps = f.recursive_deps.select do |dep|
        dep.installed? and not dep.keg_only? and not dep.linked_keg.directory?
      end
      raise CannotInstallFormulaError,
        "You must `brew link #{unlinked_deps*' '}' before #{f} can be installed" unless unlinked_deps.empty?
    end

  rescue FormulaUnavailableError => e
    # this is sometimes wrong if the dependency chain is more than one deep
    # but can't easily fix this without a rewrite FIXME-brew2
    e.dependent = f.name
    raise
  end

  def install
    # not in initialize so upgrade can unlink the active keg before calling this
    # function but after instantiating this class so that it can avoid having to
    # relink the active keg if possible (because it is slow).
    if f.linked_keg.directory?
      # some other version is already installed *and* linked
      raise CannotInstallFormulaError, <<-EOS.undent
        #{f}-#{f.linked_keg.realpath.basename} already installed at #{f.linked_keg}
        To install this version, first `brew unlink #{f}'
      EOS
    end

    unless ignore_deps
      needed_deps = []
      needed_reqs = []

      # HACK: If readline is present in the dependency tree, it will clash
      # with the stdlib's Readline module when the debugger is loaded
      if f.recursive_deps.any? { |d| d.name == "readline" } and ARGV.debug?
        ENV['HOMEBREW_NO_READLINE'] = '1'
      end

      ARGV.filter_for_dependencies do
        needed_deps = f.recursive_deps.reject{ |d| d.installed? }
        needed_reqs = f.recursive_requirements.reject { |r| r.satisfied? }
      end

      unless needed_reqs.empty?
        puts needed_reqs.map { |r| r.message } * "\n"
        fatals = needed_reqs.select { |r| r.fatal? }
        raise UnsatisfiedRequirements.new(f, fatals) unless fatals.empty?
      end

      unless needed_deps.empty?
        needed_deps.each do |dep|
          if dep.explicitly_requested?
            install_dependency dep
          else
            ARGV.filter_for_dependencies do
              # Re-create the formula object so that args like `--HEAD` won't
              # affect properties like the installation prefix. Also need to
              # re-check installed status as the Formula may have changed.
              dep = Formula.factory dep.path
              install_dependency dep unless dep.installed?
            end
          end
        end
        # now show header as all the deps stuff has clouded the original issue
        @show_header = true
      end
    end

    oh1 "Installing #{f}" if show_header

    @@attempted ||= Set.new
    raise FormulaInstallationAlreadyAttemptedError, f if @@attempted.include? f
    @@attempted << f

    if install_bottle
      pour
    else
      build
      clean
    end

    opoo "Nothing was installed to #{f.prefix}" unless f.installed?
  end

  def install_dependency dep
    dep_tab = Tab.for_formula(dep)
    outdated_keg = Keg.new(dep.linked_keg.realpath) rescue nil

    fi = FormulaInstaller.new(dep, dep_tab)
    fi.ignore_deps = true
    fi.show_header = false
    oh1 "Installing #{f} dependency: #{dep}"
    outdated_keg.unlink if outdated_keg
    fi.install
    fi.caveats
    fi.finish
  ensure
    # restore previous installation state if build failed
    outdated_keg.link if outdated_keg and not dep.installed? rescue nil
  end

  def caveats
    unless f.caveats.to_s.strip.empty?
      ohai "Caveats", f.caveats
      @show_summary_heading = true
    end

    if f.keg_only?
      ohai 'Caveats', f.keg_only_text
      @show_summary_heading = true
    else
      audit_bin
      audit_sbin
      audit_lib
      check_manpages
      check_infopages
    end

    keg = Keg.new(f.prefix)

    if keg.completion_installed? :bash
      ohai 'Caveats', <<-EOS.undent
        Bash completion has been installed to:
          #{HOMEBREW_PREFIX}/etc/bash_completion.d
        EOS
    end

    if keg.completion_installed? :zsh
      ohai 'Caveats', <<-EOS.undent
        zsh completion has been installed to:
          #{HOMEBREW_PREFIX}/share/zsh/site-functions
        EOS
    end
  end

  def finish
    ohai 'Finishing up' if ARGV.verbose?

    if f.keg_only?
      begin
        Keg.new(f.prefix).optlink
      rescue Exception => e
        onoe "Failed to create: #{f.opt_prefix}"
        puts "Things that depend on #{f} will probably not build."
      end
    else
      link
      check_PATH unless f.keg_only?
    end

    install_plist
    fix_install_names

    ohai "Summary" if ARGV.verbose? or show_summary_heading
    print "#{f.prefix}: #{f.prefix.abv}"
    print ", built in #{pretty_duration build_time}" if build_time
    puts
  end

  def build_time
    @build_time ||= Time.now - @start_time unless install_bottle or ARGV.interactive? or @start_time.nil?
  end

  def build
    FileUtils.rm Dir["#{HOMEBREW_LOGS}/#{f}/*"]

    @start_time = Time.now

    # 1. formulae can modify ENV, so we must ensure that each
    #    installation has a pristine ENV when it starts, forking now is
    #    the easiest way to do this
    # 2. formulae have access to __END__ the only way to allow this is
    #    to make the formula script the executed script
    #read, write = IO.pipe
    # I'm guessing this is not a good way to do this, but I'm no UNIX guru
    #ENV['HOMEBREW_ERROR_PIPE'] = write.to_i.to_s

    args = ARGV.clone
    args.concat tab.used_options unless tab.nil? or args.include? '--fresh'
    # FIXME: enforce the download of the non-bottled package
    # in the spawned Ruby process.
    args << '--build-from-source'
    args.uniq! # Just in case some dupes were added

    cmdargs = [
      'ruby',
      '-I', 
      Pathname.new(__FILE__).dirname,
      '-rbuild',
      '--',
      f.path,
      *args.options_only
    ]
    command = "sh -c '#{cmdargs.join(' ')}'"

    Process.spawn command

    Process.wait
    raise Interrupt if $?.exitstatus == 130
    raise "Suspicious installation failure" unless $?.success?

    raise "Empty installation" if Dir["#{f.prefix}/*"].empty?

    Tab.for_install(f, args).write # INSTALL_RECEIPT.json

  rescue Exception => e
    ignore_interrupts do
      # any exceptions must leave us with nothing installed
      ohai "Should remove #{f.prefix} but leaving it for inspection"
      #f.prefix.rmtree if f.prefix.directory?
      #f.rack.rmdir_if_possible
    end
    raise
  end

  def link
    if f.linked_keg.directory? and f.linked_keg.realpath == f.prefix
      opoo "This keg was marked linked already, continuing anyway"
      # otherwise Keg.link will bail
      f.linked_keg.unlink
    end

    keg = Keg.new(f.prefix)

    begin
      keg.link
    rescue Exception => e
      onoe "The `brew link` step did not complete successfully"
      puts "The formula built, but is not symlinked into #{HOMEBREW_PREFIX}"
      puts "You can try again using `brew link #{f.name}'"
      ohai e, e.backtrace if ARGV.debug?
      @show_summary_heading = true
      ignore_interrupts{ keg.unlink }
      raise unless e.kind_of? RuntimeError
    end
  end

  def install_plist
    # Install a plist if one is defined
    # Skip plist file exists check: https://github.com/mxcl/homebrew/issues/15849
    if f.startup_plist
      f.plist_path.write f.startup_plist
      f.plist_path.chmod 0644
    end
  end

  def fix_install_names
    Keg.new(f.prefix).fix_install_names
  rescue Exception => e
    onoe "Failed to fix install names"
    puts "The formula built, but you may encounter issues using it or linking other"
    puts "formula against it."
    ohai e, e.backtrace if ARGV.debug?
    @show_summary_heading = true
  end

  def clean
    ohai "Cleaning" if ARGV.verbose?
    if f.class.skip_clean_all?
      opoo "skip_clean :all is deprecated"
      puts "Skip clean was commonly used to prevent brew from stripping binaries."
      puts "brew no longer strips binaries, if skip_clean is required to prevent"
      puts "brew from removing empty directories, you should specify exact paths"
      puts "in the formula."
      return
    end
    require 'cleaner'
    Cleaner.new f
  rescue Exception => e
    opoo "The cleaning step did not complete successfully"
    puts "Still, the installation was successful, so we will link it into your prefix"
    ohai e, e.backtrace if ARGV.debug?
    @show_summary_heading = true
  end

  def pour
    fetched, downloader = f.fetch
    f.verify_download_integrity fetched
    HOMEBREW_CELLAR.cd do
      downloader.stage
    end
  end

  ## checks

  def check_PATH
    # warn the user if stuff was installed outside of their PATH
    [f.bin, f.sbin].each do |bin|
      if bin.directory? and bin.children.length > 0
        bin = (HOMEBREW_PREFIX/bin.basename).realpath
        unless ORIGINAL_PATHS.include? bin
          opoo "#{bin} is not in your PATH"
          puts "You can amend this by altering your ~/.bashrc file"
          @show_summary_heading = true
        end
      end
    end
  end

  def check_manpages
    # Check for man pages that aren't in share/man
    if (f.prefix+'man').directory?
      opoo 'A top-level "man" directory was found.'
      puts "Homebrew requires that man pages live under share."
      puts 'This can often be fixed by passing "--mandir=#{man}" to configure.'
      @show_summary_heading = true
    end
  end

  def check_infopages
    # Check for info pages that aren't in share/info
    if (f.prefix+'info').directory?
      opoo 'A top-level "info" directory was found.'
      puts "Homebrew suggests that info pages live under share."
      puts 'This can often be fixed by passing "--infodir=#{info}" to configure.'
      @show_summary_heading = true
    end
  end

  def check_jars
    return unless f.lib.directory?

    jars = f.lib.children.select{|g| g.to_s =~ /\.jar$/}
    unless jars.empty?
      opoo 'JARs were installed to "lib".'
      puts "Installing JARs to \"lib\" can cause conflicts between packages."
      puts "For Java software, it is typically better for the formula to"
      puts "install to \"libexec\" and then symlink or wrap binaries into \"bin\"."
      puts "See \"activemq\", \"jruby\", etc. for examples."
      puts "The offending files are:"
      puts jars
      @show_summary_heading = true
    end
  end

  def check_non_libraries
    return unless f.lib.directory?

    valid_extensions = %w(.a .dll .lib .jnilib .la .o .so
                          .jar .prl .pm .sh)
    non_libraries = f.lib.children.select do |g|
      next if g.directory?
      not valid_extensions.include? g.extname
    end

    unless non_libraries.empty?
      opoo 'Non-libraries were installed to "lib".'
      puts "Installing non-libraries to \"lib\" is bad practice."
      puts "The offending files are:"
      puts non_libraries
      @show_summary_heading = true
    end
  end

  def audit_bin
    return unless f.bin.directory?

    non_exes = f.bin.children.select { |g| g.directory? or not g.executable? }

    unless non_exes.empty?
      opoo 'Non-executables were installed to "bin".'
      puts "Installing non-executables to \"bin\" is bad practice."
      puts "The offending files are:"
      puts non_exes
      @show_summary_heading = true
    end
  end

  def audit_sbin
    return unless f.sbin.directory?

    non_exes = f.sbin.children.select { |g| g.directory? or not g.executable? }

    unless non_exes.empty?
      opoo 'Non-executables were installed to "sbin".'
      puts "Installing non-executables to \"sbin\" is bad practice."
      puts "The offending files are:"
      puts non_exes
      @show_summary_heading = true
    end
  end

  def audit_lib
    check_jars
    check_non_libraries
  end
end


class Formula
  def keg_only_text
    s = "This formula is keg-only: so it was not symlinked into #{HOMEBREW_PREFIX}."
    s << "\n\n#{keg_only_reason.to_s}"
    if lib.directory? or include.directory?
      s <<
        <<-EOS.undent_________________________________________________________72


        Generally there are no consequences of this for you. If you build your
        own software and it requires this formula, you'll need to add to your
        build variables:

        EOS
      s << "    LDFLAGS:  -L#{HOMEBREW_PREFIX}/opt/#{name}/lib\n" if lib.directory?
      s << "    CPPFLAGS: -I#{HOMEBREW_PREFIX}/opt/#{name}/include\n" if include.directory?
    end
    s << "\n"
  end
end
