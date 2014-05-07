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

    def remove_build(version)
      raise "Build #{version.fg("blue")} not found" unless build_exists? version
      FileUtils.rm_rf "#{@repo.location}/packages/#{@name}/builds/#{version}"
    end

    def <=>(o)
      self.name <=> o.name
    end
  end
end
