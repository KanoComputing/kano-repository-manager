# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "dr/gitpackage"
require "dr/debpackage"

require "dr/shellcmd"
require "dr/logger"
require "dr/gnupg"
require "dr/buildroot"

require "fileutils"
require "yaml"

module Dr
  class AlreadyExists < StandardError; end

  class Repo
    include Logger

    attr_reader :location

    def initialize(loc)
      @location = File.expand_path loc

      @packages_dir = "#{@location}/packages"

      meta = "#{@location}/metadata"
      @metadata = File.exists?(meta) ? YAML.load_file(meta) : {}
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

          if conf[:name].length > 0
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
      FileUtils.mkdir_p "#{@location}/buildroots"

      @metadata = {"base-os" => conf[:base]}
      File.open("#{@location}/metadata", "w" ) do |out|
        YAML.dump(@metadata)
      end

      conf[:arches].each do |arch|
        buildroot arch
      end
    end

    def list_packages(suite=nil)
      pkgs = []

      if suite
        Dir.foreach @packages_dir do |pkg_name|
          unless pkg_name =~ /^\./
            versions = get_subpackage_versions pkg_name
            unless versions[codename_to_suite suite].empty?
              pkgs.push get_package pkg_name
            end
          end
        end
      else
        Dir.foreach @packages_dir do |pkg_name|
          pkgs.push get_package pkg_name unless pkg_name =~ /^\./
        end
      end

      pkgs.sort
    end

    def buildroot(arch)
      cache_dir = "#{@location}/buildroots/"
      BuildRoot.new @metadata["base-os"], arch, cache_dir
    end

    def get_package(name)
      unless File.exists? "#{@packages_dir}/#{name}"
        raise "Package #{name.style "pkg-name"} doesn't exist in the repo"
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

    def query_for_deb_version(suite, pkg_name)
      reprepro_cmd = "reprepro --basedir #{location}/archive " +
                     "--list-format '${version}' list #{suite} " +
                     "#{pkg_name} 2>/dev/null"
      reprepro = ShellCmd.new reprepro_cmd, :tag => "reprepro"
      v = reprepro.out.chomp
      v = nil unless v.length > 0
      v
    end

    def suite_has_package?(suite, pkg_name)
      pkg_versions = get_subpackage_versions(pkg_name)[codename_to_suite(suite)]

      pkg_versions.length > 0
    end

    def suite_has_higher_pkg_version?(suite, pkg, version)
      used_versions = get_subpackage_versions(pkg.name)[codename_to_suite(suite)]

      has_higher_version = false
      used_versions.each do |subpkg_name, subpkg_version|
        if subpkg_version.to_s >= version.to_s
          has_higher_version = true
        end
      end
      has_higher_version
    end

    def get_subpackage_versions(pkg_name)
      pkg = get_package pkg_name
      suites = get_suites

      versions = {}
      suites.each do |suite, codename|
        versions[suite] = {}
        reprepro_cmd = "reprepro --basedir #{location}/archive " +
                     "--list-format '${package} ${version}\n' " +
                     "listfilter #{suite} 'Source (== #{pkg_name}) | " +
                     "Package (== #{pkg_name})' " +
                     "2>/dev/null"
        reprepro = ShellCmd.new reprepro_cmd, :tag => "reprepro"
        reprepro.out.chomp.each_line do |line|
          subpkg, version = line.split(" ").map(&:chomp)
          versions[suite][subpkg] = version
        end
      end
      versions
    end

    def push(pkg_name, version, suite, force=false)
      pkg = get_package pkg_name

      if version
        unless pkg.build_exists? version
          raise "Build version '#{version}' not found"
        end
      else
        if pkg.history.length == 0
          log :err, "No built packages available for #{pkg_name}"
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

      debs = Dir["#{@location}/packages/#{pkg.name}/builds/#{version}/*"]
      names = debs.map { |deb| File.basename(deb).split("_")[0] }

      used_versions = get_subpackage_versions(pkg.name)[codename_to_suite(suite)]

      is_of_higher_version = true
      names.each do |name|
        if used_versions.has_key?(name) && version <= used_versions[name]
          is_of_higher_version = false
        end
      end

      unless is_of_higher_version
        log :warn, "The #{suite} suite already contains " +
                   "#{pkg.name.style "pkg-name"} version " +
                   "#{version.to_s.style "version"}"
        if force
          reprepro = "reprepro -b #{@location}/archive " +
                     "--gnupghome #{location}/gnupg-keyring/ removesrc " +
                     "#{suite} #{pkg.name}"
          ShellCmd.new reprepro, :tag => "reprepro", :show_out => false
        else
          log :warn, "The same package of a higher version is already in the " +
                     "#{suite} suite."

          raise AlreadyExists.new "Push failed"
        end
      end

      log :info, "Pushing #{pkg_name.style "pkg-name"} version " +
                 "#{version.to_s.style "version"} to #{suite}"
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

      log :info, "Removing #{pkg_name.style "pkg-name"} from #{suite}"
      reprepro = "reprepro -b #{@location}/archive " +
                 "--gnupghome #{location}/gnupg-keyring/ removesrc " +
                 "#{suite} #{pkg.name}"
      ShellCmd.new reprepro, :tag => "reprepro", :show_out => true
    end

    def remove(pkg_name, force=false)
      pkg = get_package pkg_name

      if is_used? pkg_name
        log :warn, "The #{pkg_name.style "pkg-name"} package is still used"
        raise "Operation canceled, add -f to remove anyway" unless force

        log :info, "Will be force-removed anyway"
        versions = get_subpackage_versions(pkg_name)
        get_suites.each do |suite, codename|
          unpush pkg_name, suite unless versions[suite].empty?
        end
      end

      log :info, "Removing #{pkg_name.style "pkg-name"} from the repository"
      FileUtils.rm_rf "#{location}/packages/#{pkg_name}"
    end

    def remove_build(pkg_name, version, force=false)
      pkg = get_package pkg_name

      if is_used?(pkg_name, version)
        if force
          log :info, "Force-removing #{version.style "version"} version of " +
                     "#{pkg_name.style "pkg-name"}"
          versions_by_suite = get_subpackage_versions pkg_name
          versions_by_suite.each do |suite, versions|
            unpush pkg_name, suite if versions.has_value? version
          end
        else
          log :warn, "This build of #{pkg_name.style "pkg-name"} is " +
                     "still being used, add -f to force-remove"
          return
        end
      else
        log :info, "Removing the #{version.style "version"} version of " +
                   "#{pkg_name.style "pkg-name"}"
      end

      pkg.remove_build version
    end

    def get_build(pkg_name, version=nil)
      pkg = get_package pkg_name

      hist = pkg.history
      raise "The package hasn't been built yet." unless hist.length > 0
      version = hist[0] unless version

      unless pkg.build_exists? version
        raise "Build #{version.style "version"} doesn't exist"
      end

      Dir["#{@location}/packages/#{pkg.name}/builds/#{version}/*"]
    end

    def get_build_metadata(pkg_name, version)
      pkg = get_package pkg_name
      raise "Build #{version} doesn't exist" unless pkg.build_exists? version

      md_file = "#{@location}/packages/#{pkg.name}/builds/#{version}/.metadata"
      if File.exists? md_file
        YAML.load_file md_file
      else
        {}
      end
    end

    def sign_deb(deb)
      keyring = "#{@location}/gnupg-keyring"
      gpg = GnuPG.new keyring
      key_id = gpg.get_key_id get_key

      cmd = "dpkg-sig -k '#{key_id}' -s builder -g '--homedir #{keyring}' #{deb}"
      ShellCmd.new cmd, :tag => "dpkg-sig", :show_out => true
    end

    def codename_to_suite(codename_or_suite)
      get_suites.each do |suite, codename|
        return suite if codename_or_suite == suite || codename_or_suite == codename
      end

      nil
    end

    private
    def get_key
      File.open "#{@location}/archive/conf/distributions", "r" do |f|
        f.each_line do |line|
          m = line.match /^SignWith: (.+)/
          return m.captures[0] if m
        end
      end
    end

    def is_used?(pkg_name, version=nil)
      versions_by_suite = get_subpackage_versions pkg_name
      versions_by_suite.inject(false) do |rslt, hash_pair|
        suite, versions = hash_pair
        if version == nil
          rslt || !versions.empty?
        else
          rslt || versions.has_value?(version)
        end
      end
    end
  end
end
