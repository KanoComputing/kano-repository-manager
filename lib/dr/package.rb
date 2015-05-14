# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "dr/logger"
require "dr/shellcmd"

module Dr
  class Package
    class UnableToBuild < RuntimeError
    end

    class BuildFailed < RuntimeError
    end

    attr_reader :name

    include Logger
    class << self
      include Logger
    end

    def initialize(name, repo)
      @name = name
      @repo = repo
    end

    def history
      versions = []
      Dir.foreach "#{@repo.location}/packages/#{name}/builds/" do |v|
        versions.push v unless v =~ /^\./
      end

      versions.sort.reverse
    end

    def build_exists?(version)
      File.directory? "#{@repo.location}/packages/#{@name}/builds/#{version}"
    end

    # Returns the highest build of this version
    #
    # @param [PkgVersion] base_version  The version number to look for.
    def get_highest_build(base_version)
      base = base_version.clone
      base.build = 0
      builds_dir = "#{@repo.location}/packages/#{@name}/builds/"

      versions = Dir["#{builds_dir}/#{base_version}*"].map do |dir|
        PkgVersion.new File.basename dir
      end

      if versions.length > 0
        versions.max
      else
        base_version
      end
    end

    # Verify whether the build is complete and ready to be pushed
    #
    # @param [String] version  The build version to be checked.
    def check_build(version)
      raise "Build #{version} of #{@name} not found." unless build_exists? version

      build_path = "#{@repo.location}/packages/#{@name}/builds/#{version}"

      debs = Dir["#{build_path}/*.deb"]
      unless debs.length > 0
        raise "Build #{version} of #{@name} seems to be broken."
      end
    end

    def remove_build(version)
      raise "Build #{version.fg("blue")} not found" unless build_exists? version
      FileUtils.rm_rf "#{@repo.location}/packages/#{@name}/builds/#{version}"
    end

    def get_configuration
      {}
    end

    def set_configuration(config)
      raise "This package isn't configurable"
    end

    def <=>(o)
      self.name <=> o.name
    end
  end
end
