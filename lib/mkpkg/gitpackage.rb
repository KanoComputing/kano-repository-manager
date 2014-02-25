require "mkpkg/package"
require "mkpkg/pkgversion"

module Mkpkg
  class GitPackage < Package
    def self.setup(repo, git_addr, default_branch, force=false)
      Dir.mktmpdir do |tmp|
        `git clone --branch #{default_branch} #{git_addr} #{tmp}/git`

        unless File.exists? "#{tmp}/git/debian/control"
          raise "The debian packaging files were not found in the repository."
        end

        src_name = nil
        File.open "#{tmp}/git/debian/control", "r" do |f|
          f.each_line do |line|
            match = line.match /^Source: (.+)$/
            if match
              src_name = match.captures[0]
              break
            end
          end
        end

        unless src_name
          raise "Couldn't identify the source package. " +
                "Is your control file well formed?"
        end

        pkg_dir = "#{repo.location}/packages/#{src_name}"
        if File.exists? pkg_dir
          raise "The package already exists. Add -f to insert it anyway."
        end

        FileUtils.mkdir_p "#{pkg_dir}"
        FileUtils.mkdir_p "#{pkg_dir}/builds"

        FileUtils.mv "#{tmp}/git/.git", "#{pkg_dir}/source"
      end
    end

    def initialize(name, repo)
      super name, repo

      @git_dir = "#{repo.location}/packages/#{name}/source"
      @default_branch = `git --git-dir #{@git_dir} branch`.chomp.lines.grep(/^*/)[0][2..-1]
    end

    def build(branch=nil, force=false)
      branch = @default_branch unless branch

      version = nil
      orig_rev, curr_rev = update_from_origin branch
      if curr_rev != orig_rev || force
        @repo.buildroot do |br|
          src_dir = "#{br}/source"
          FileUtils.mkdir_p src_dir

          puts "Extracting sources ..."
          Kernel.system "git --git-dir #{@git_dir} archive " +
                        "--format tar #{branch} | tar x -C #{src_dir}"

          version = PkgVersion.new get_version "#{src_dir}/debian/changelog"

          while build_exists? version
            version.increment!
          end

          now = Time.new.strftime("%a, %-d %b %Y %T %z")
          ch_entry = "#{@name} (#{version}) kano; urgency=low\n"
          ch_entry << "\n"
          ch_entry << "  * Package rebuilt, updated to revision #{curr_rev[0..7]}.\n"
          ch_entry << "\n"
          ch_entry << " -- Team Kano <dev@kano.me>  #{now}\n\n"

          changelog = ""
          File.open "#{src_dir}/debian/changelog", "r" do |f|
            changelog = f.read
          end

          File.open "#{src_dir}/debian/changelog", "w" do |f|
            f.write ch_entry
            f.write changelog
          end

          Kernel.system <<-EOS
sudo chroot "#{br}" <<EOF
apt-get update

dpkg-source -b "/source"

mk-build-deps *.dsc -i -t "apt-get --no-install-recommends -y"
rm -rf #{@name}-build-deps_*

cd /source
debuild -i -uc -us -b
EOF
EOS

          expected_pkgs = get_subpackage_names "#{src_dir}/debian/control", version
          p expected_pkgs
          expected_pkgs.each do |pkg|
            unless File.exists? "#{br}/#{pkg}"
              raise "Build failed, '#{pkg}' package not build."
            end
          end

          build_dir = "#{@repo.location}/packages/#{@name}/builds/#{version}"
          FileUtils.mkdir_p build_dir
          expected_pkgs.each do |pkg|
            FileUtils.cp "#{br}/#{pkg}", build_dir
          end
        end
      end
      version
    end

    def build_exists?(version)
      File.directory? "#{@repo.location}/packages/#{@name}/builds/#{version}"
    end

    private
    def update_from_origin(branch)
      original_rev = `git --git-dir #{@git_dir} rev-parse #{branch} 2>/dev/null`.chomp
      original_rev = nil if original_rev == branch

      rv = if @default_branch == branch
        Kernel.system "git --git-dir #{@git_dir} pull origin #{branch}"
      else
        Kernel.system "git --git-dir #{@git_dir} fetch origin #{branch}:#{branch}"
      end
      raise "Unable to pull from origin." unless rv

      current_rev = `git --git-dir #{@git_dir} rev-parse #{branch}`.chomp

      [original_rev, current_rev]
    end

    def get_version(changelog_file)
      File.open changelog_file, "r" do |f|
        f.each_line do |l|
          version = l.match /^#{@name} \(([^\)]+)\) .+;/
          return version.captures[0] if version
        end
      end

      nil
    end

    def get_subpackage_names(control_file, version)
      packages = []
      File.open control_file, "r" do |f|
        current_pkg = nil
        f.each_line do |l|
          if /^Package: / =~ l
            current_pkg = l.split(" ")[1]
          end
          if /^Architecture: / =~ l
            arches = l.split(/\s+/)[1..-1].each do |arch|
              packages.push "#{current_pkg}_#{version}_#{arch}.deb"
            end
          end
        end
      end

      packages
    end
  end
end
