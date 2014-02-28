require "mkpkg/gitpackage"
require "mkpkg/debpackage"

require "mkpkg/shellcmd"
require "mkpkg/logger"
require "mkpkg/gnupg"
require "mkpkg/buildroot"

require "fileutils"

module Mkpkg
  class Repo
    include Logger

    attr_reader :location

    def initialize(loc)
      @location = File.expand_path loc

      @packages_dir = "#{@location}/packages"
    end

    def setup(conf)
      log :info, "Creating the archive directory"

      begin
        FileUtils.mkdir_p location
      rescue Exception => e
        log :err, "Unable to create a directory at '#{@location.fg("blue")}'"
        raise e
      end

      FileUtils.mkdir_p "#{@location}/archive"

      gpg = GnuPG.new "#{@location}/gnupg-keyring"
      key = gpg.generate_key conf[:gpg_name], conf[:gpg_mail], conf[:gpg_pass]
      gpg.export_pub key, "#{@location}/archive/repo.gpg.key"

      log :info, "Writing the configuration file"
      FileUtils.mkdir_p "#{@location}/archive/conf"
      File.open "#{@location}/archive/conf/distributions", "w" do |f|
        conf[:suites].each_with_index do |s, i|
          f.puts "Suite: #{s}"

          if conf[:codenames][i].length > 0
            f.puts "Codename: #{conf[:codenames][i]}"
          end

          if conf[:name][i].length > 0
            f.puts "Origin: #{conf[:name]} - #{s}"
            f.puts "Label: #{conf[:name]} - #{s}"
          end

          if conf[:desc].length > 0
            f.puts "Description: #{conf[:desc]}"
          end

          f.puts "Architectures: #{conf[:arches].join " "}"
          f.puts "Components: #{conf[:components].join " "}"

          f.puts "SignWith: #{key}"
          f.puts ""
        end
      end

      FileUtils.mkdir_p @packages_dir

      conf[:arches].each do |arch|
        BuildRoot.new arch, "#{@location}/build-root-#{arch}.tar.gz"
      end
    end

    def list_packages(suite=nil)
      pkgs = []
      if suite
        a = 1
      else
        Dir.foreach @packages_dir do |pkg_name|
          pkgs.push get_package pkg_name unless pkg_name =~ /^\./
        end
      end

      pkgs
    end

    def buildroot(arch)
      BuildRoot.new arch, "#{@location}/build-root-#{arch}.tar.gz"
    end

    def get_package(name)
      unless File.exists? "#{@packages_dir}/#{name}"
        raise "Package '#{name}' doesn't exist in the repo."
      end

      if File.exists? "#{@packages_dir}/#{name}/source"
        GitPackage.new name, self
      else
        DebPackage.new name, self
      end
    end

    def get_suites
      suites = nil
      File.open "#{@location}/archive/conf/distributions", "r" do |f|
        suites = f.read.split "\n\n"
      end

      suites.map do |s|
        suite = nil
        codename = nil
        s.each_line do |l|
          m = l.match /^Suite: (.+)/
          suite = m.captures[0].chomp if m

          m = l.match /^Codename: (.+)/
          codename = m.captures[0].chomp if m
        end
        [suite, codename]
      end
    end

    def get_architectures
      arches = []
      File.open "#{@location}/archive/conf/distributions", "r" do |f|
        f.each_line do |l|
          m = l.match /^Architectures: (.+)/
          arches += m.captures[0].chomp.split(" ") if m
        end
      end

      arches.uniq
    end

    def query_for_version(suite, pkg_name)
      reprepro = "reprepro --basedir #{location}/archive " +
                 "--list-format '${version}' list #{suite} " +
                 "#{pkg_name} 2>/dev/null"
      reprepro_cmd = ShellCmd.new reprepro, :tag => "reprepro"
      v = reprepro_cmd.out.chomp
      v = nil unless v.length > 0
      v
    end

    def push(pkg_name, version, suite, force=false)
      pkg = get_package pkg_name

      if version
        unless pkg.build_exists? version
          raise "Build version '#{version}' not found"
        end
      else
        if pkg.history.length == 0
          log :err, "Package #{pkg_name} has not been built yet"
          log :err, "Please, run a build first and the push."
          raise "Push failed"
        end
        version = pkg.history[0]
      end

      if suite
        cmp = get_suites.map { |n, cn| suite == n || suite == cn }
        suite_exists = cmp.inject(false) { |r, o| r || o }
        raise "Suite '#{suite}' doesn't exist." unless suite_exists
      else
        # FIXME: This should be configurable
        suite = "testing"
      end

      current_version = query_for_version suite, pkg.name

      if current_version != nil && current_version >= version
        log :warn, "Version #{version.fg("blue")} already available in #{suite}"
        if force
          reprepro = "reprepro -b #{@location}/archive " +
                     "--gnupghome #{location}/gnupg-keyring/ removesrc " +
                     "#{suite} #{pkg.name}"
          ShellCmd.new reprepro, :tag => "reprepro", :show_out => true
        else
          log :err, "The same package of a higher version is already in the repo."
          raise "Push failed"
        end
      end

      log :info, "Pushing #{pkg_name} version #{version} to #{suite}"
      debs = Dir["#{@location}/packages/#{pkg.name}/builds/#{version}/*"]
      reprepro = "reprepro -b #{@location}/archive " +
                 "--gnupghome #{location}/gnupg-keyring/ includedeb " +
                 "#{suite} #{debs.join " "}"
      ShellCmd.new reprepro, :tag => "reprepro", :show_out => true
    end

    def unpush(pkg_name, suite)
      pkg = get_package pkg_name

      cmp = get_suites.map { |n, cn| suite == n || suite == cn }
      suite_exists = cmp.inject(false) { |r, o| r || o }
      unless suite_exists
        log :err, "Suite '#{suite}' doesn't exist."
        raise "Unpush failed"
      end

      log :info, "Removing #{pkg_name} from #{suite}"
      reprepro = "reprepro -b #{@location}/archive " +
                 "--gnupghome #{location}/gnupg-keyring/ removesrc " +
                 "#{suite} #{pkg.name}"
      ShellCmd.new reprepro, :tag => "reprepro", :show_out => true
    end

    def remove(pkg_name, force=false)
      pkg = get_package pkg_name

      versions = get_suites.map { |n, cn| query_for_version n, pkg_name }
      is_used = versions.inject(false) { |r, v| v != nil ? true : r }

      if is_used
        log :warn, "Package #{pkg_name} is still used"
        raise "The '#{pkg_name}' package is still used." unless force

        log :info, "Will be force-removed anyway"
        get_suites.zip(versions).each do |suite, version|
          log :info, "Removing #{pkg_name} v#{version} from #{suite}"
          unpush pkg_name, suite[0] if version != nil
        end
      end

      if !is_used || force
        log :info, "Removing #{pkg_name} from the repository"
        FileUtils.rm_rf "#{location}/packages/#{pkg_name}"
      end
    end

    def get_build(pkg_name, version=nil)
      pkg = get_package pkg_name

      hist = pkg.history
      raise "The package hasn't been built yet." unless hist.length > 0
      version = hist[0] unless version

      raise "Build #{version} doesn't exist" unless pkg.build_exists? version

      Dir["#{@location}/packages/#{pkg.name}/builds/#{version}/*"]
    end
  end
end
