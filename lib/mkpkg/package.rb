require "mkpkg/logger"

module Mkpkg
  class Package
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
  end
end
