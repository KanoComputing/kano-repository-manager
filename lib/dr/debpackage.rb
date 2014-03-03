require "dr/package"

module Dr
  class DebPackage < Package
    def self.setup(repo, deb_file)
      puts "Adding the #{File.basename deb_file} package ..."
      src_name = `dpkg-deb --field #{deb_file} Source`.chomp
      if src_name == ""
        src_name = `dpkg-deb --field #{deb_file} Package`.chomp
      end
      puts "Source package: #{src_name}"

      version = `dpkg-deb --field #{deb_file} Version`.chomp

      deb_dir = "#{repo.location}/packages/#{src_name}/builds/#{version}"
      FileUtils.mkdir_p deb_dir
      FileUtils.cp "#{deb_file}", "#{deb_dir}/"
    end

    def initialize(name, repo)
      super name, repo
    end
  end
end
