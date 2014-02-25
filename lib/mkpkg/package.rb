module Mkpkg
  class Package
    attr_reader :name

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
