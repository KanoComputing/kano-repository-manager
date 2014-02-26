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

      FileUtils.mkdir_p "#{@location}/packages"

      BuildRoot.new "#{@location}/build_root.tar.gz"
    end

    def list_packages
      pkgs = []
      Dir.foreach "#{@location}/packages" do |pkg_name|
        pkgs.push get_package pkg_name unless pkg_name =~ /^\./
      end

      pkgs
    end

    def buildroot
      Buildroot.new "#{@location}/build_root.tar.gz"
    end

    def get_package(name)
      unless File.exists? "#{@location}/packages/#{name}"
        raise "Package '#{name}' doesn't exist in the repo."
      end

      if File.exists? "#{@location}/packages/#{name}/source"
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

    def query_for_version(suite, pkg_name)
      v = `reprepro --basedir #{location}/archive --list-format '${version}' list #{suite} #{pkg_name} 2>/dev/null`.chomp
      v = nil unless v.length > 0
      v
    end

    def push(pkg_name, version, suite, force=false)
      pkg = get_package pkg_name

      if version
        unless pkg.build_exists? version
          raise "Build version '#{version}' not found."
        end
      else
        raise "No #{pkg_name} build found found." if pkg.history.length == 0
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
        if force
          Kernel.system "reprepro -b #{@location}/archive --gnupghome #{location}/gnupg-keyring/ removesrc #{suite} #{pkg.name}"
        else
          raise "The same package of a higher version (#{version}) is " +
                "already in the repo."
        end
      end

      debs = Dir["#{@location}/packages/#{pkg.name}/builds/#{version}/*"]
      Kernel.system "reprepro -b #{@location}/archive --gnupghome #{location}/gnupg-keyring/ includedeb #{suite} #{debs.join " "}"
    end

    def unpush(pkg_name, suite)
      pkg = get_package pkg_name

      cmp = get_suites.map { |n, cn| suite == n || suite == cn }
      suite_exists = cmp.inject(false) { |r, o| r || o }
      raise "Suite '#{suite}' doesn't exist." unless suite_exists

      version = query_for_version pkg_name, suite

      if version
        Kernel.system "reprepro -b #{@location}/archive --gnupghome #{location}/gnupg-keyring/ removesrc #{suite} #{pkg.name}"
      else
        raise "Package #{pkg_name} is not included in #{suite}."
      end
    end

    def remove(pkg_name, force=false)
      pkg = get_package pkg_name

      versions = get_suites.map { |n, cn| query_for_version pkg_name, n }
      used = versions.inject(false) { |r, v| r || true if v != nil }
      p versions
      p used

      if used
        raise "The '#{pkg_name}' package is still used." unless force

        get_suites.zip(versions).each do |suite, version|
          unpush pkg_name, suite[0] if version != nil
        end
      end

      if !used || force
        p "Would remove!"
        #FileUtils.rm_rf "#{location}/packages/#{pkg_name}"
      end
    end
  end
end
