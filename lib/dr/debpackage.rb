# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "dr/package"

module Dr
  class DebPackage < Package
    def self.setup(repo, deb_file, force=false)
      dpkg = ShellCmd.new "dpkg-deb --field #{deb_file} Source", :tag => "dpkg"
      src_name = dpkg.out.chomp
      if src_name == ""
        dpkg = ShellCmd.new "dpkg-deb --field #{deb_file} Package", :tag => "dpkg"
        src_name = dpkg.out.chomp
      end

      deb_file_name = File.basename(deb_file)
      log :info, "Adding the #{deb_file_name.style "subpkg-name"} package"

      dpkg = ShellCmd.new "dpkg-deb --field #{deb_file} Version", :tag => "dpkg"
      version = dpkg.out.chomp

      deb_dir = "#{repo.location}/packages/#{src_name}/builds/#{version}"

      if File.exist?("#{deb_dir}/#{deb_file_name}") && !force
        raise "This deb file is already in the repo"
      end

      log :info, "Adding a build to the #{src_name.style "pkg-name"} source package"
      FileUtils.mkdir_p deb_dir
      FileUtils.cp deb_file.to_s, "#{deb_dir}/"

      log :info, "Signing the deb file"
      repo.sign_deb "#{deb_dir}/#{deb_file_name}"
    end

    def initialize(name, repo)
      super name, repo
    end

    def build(branch=nil, force=false)
      log :warn, "The sources of the #{@name.style "pkg-name"} package are " +
                 "not managed by #{"dr".bright}"
      raise UnableToBuild.new "Unable to build the package"
    end
  end
end
