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

      log :info, "Adding the #{File.basename(deb_file).fg("blue")} package"

      dpkg = ShellCmd.new "dpkg-deb --field #{deb_file} Version", :tag => "dpkg"
      version = dpkg.out.chomp

      deb_dir = "#{repo.location}/packages/#{src_name}/builds/#{version}"

      if File.exists?("#{deb_dir}/#{File.basename deb_file}") && !force
        raise "This deb file is already in the repo"
      end

      log :info, "Adding a build to the #{src_name.fg "blue"} source package"

      FileUtils.mkdir_p deb_dir
      FileUtils.cp "#{deb_file}", "#{deb_dir}/"
    end

    def initialize(name, repo)
      super name, repo
    end

    def build(branch=nil, force=false)
      log :warn, "The source of the #{@name.fg "blue"} package is not " +
                 "managed by #{"dr".bright}"
      raise "Unable to build the package"
    end
  end
end
