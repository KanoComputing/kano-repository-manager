require "dr/package"
require "dr/pkgversion"
require "dr/shellcmd"

module Dr
  class GitPackage < Package
    def self.setup(repo, git_addr, default_branch, force=false)
      Dir.mktmpdir do |tmp|
        git_cmd = "git clone --branch #{default_branch} #{git_addr} #{tmp}/git"
        ShellCmd.new git_cmd, :tag => "git", :show_out => true

        unless File.exists? "#{tmp}/git/debian/control"
          log :err, "The debian packaging files not found in the repository"
          raise "Adding a package from #{git_addr} failed"
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
          log :err, "Couldn't identify the source package"
          raise "Adding a package from #{git_addr} failed"
        end

        pkg_dir = "#{repo.location}/packages/#{src_name}"
        if File.exists? pkg_dir
          log :warn, "The package already exists. Add -f to insert it anyway."
          raise "Adding failed"
        end

        log :info, "Adding #{src_name.fg "blue"} to the repository"
        FileUtils.mkdir_p "#{pkg_dir}"

        log :info, "Setting up builds directory"
        FileUtils.mkdir_p "#{pkg_dir}/builds"

        log :info, "Setting up the source directory"
        FileUtils.mv "#{tmp}/git/.git", "#{pkg_dir}/source"

        log :info, "Package #{src_name} added successfully"
      end
    end

    def initialize(name, repo)
      super name, repo

      @git_dir = "#{repo.location}/packages/#{name}/source"

      git_cmd = ShellCmd.new "git --git-dir #{@git_dir} branch", {
        :tag => "git-clone"
      }
      @default_branch = git_cmd.out.chomp.lines.grep(/^*/)[0][2..-1]
    end

    def build(branch=nil, force=false)
      branch = @default_branch unless branch

      version = nil
      orig_rev, curr_rev = update_from_origin branch
      if curr_rev != orig_rev || force
        Dir.mktmpdir do |src_dir|
          log :info, "Extracting the sources"
          git_cmd ="git --git-dir #{@git_dir} archive " +
                   "--format tar #{branch} | tar x -C #{src_dir}"
          ShellCmd.new git_cmd, :tag => "git", :show_out => true

          version = PkgVersion.new get_version "#{src_dir}/debian/changelog"
          log :info, "Source version: #{version}"

          while build_exists? version
            version.increment!
          end
          log :info, "Building version: #{version}"

          log :info, "Updating changelog"
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

          repo_arches = @repo.get_architectures
          pkg_arches = get_architectures("#{src_dir}/debian/control")
          arches = case
          when pkg_arches.include?("any") || pkg_arches.include?("all")
            repo_arches
          else
            repo_arches & pkg_arches
          end
          arches.each do |arch|
            @repo.buildroot(arch).open do |br|
              log :info, "Building the #{@name.fg("blue")} package " +
                         "v#{version} for #{arch}"
              # Moving to the proper directory
              build_dir_name = "#{@name}-#{version.upstream}"
              build_dir = "#{br}/#{build_dir_name}"
              FileUtils.cp_r src_dir, build_dir

              # Make orig tarball
              log :info, "Creating orig source tarball"
              tar = "tar cz -C #{build_dir} --exclude=debian " +
                    "-f #{br}/#{@name}_#{version.upstream}.orig.tar.gz " +
                    "`ls -1 #{build_dir}`"
              ShellCmd.new tar, :tag => "tar"

              apt = "sudo chroot #{br} apt-get update"
              deps = <<-EOS
sudo chroot #{br} <<EOF
dpkg-source -b "/#{build_dir_name}"
mk-build-deps *.dsc -i -t "apt-get --no-install-recommends -y"
rm -rf #{@name}-build-deps_*
EOF
EOS
          build = <<-EOS
sudo chroot #{br} <<EOF
cd /#{build_dir_name}
debuild -i -uc -us -b
EOF
EOS

              log :info, "Updating the sources lists"
              ShellCmd.new apt, :tag => "apt-get", :show_out => true

              log :info, "Installing build dependencies"
              ShellCmd.new deps, :tag => "mk-build-deps", :show_out => true

              log :info, "Building the package"
              ShellCmd.new build, :tag => "debuild", :show_out => true

              debs = Dir["#{br}/*.deb"]
              expected_pkgs = get_subpackage_names "#{src_dir}/debian/control"
              expected_pkgs.each do |subpkg_name|
                includes = debs.inject(false) do |r, n|
                  r || ((/^#{br}\/#{subpkg_name}_#{version}/ =~ n) != nil)
                end

                unless includes
                  log :err, "Subpackage #{subpkg_name} did not build properly"
                  raise "Building #{name} failed"
                end
              end

              build_dir = "#{@repo.location}/packages/#{@name}/builds/#{version}"
              FileUtils.mkdir_p build_dir
              debs.each do |pkg|
                FileUtils.cp pkg, build_dir
              end
            end
          end
        end
      else
        log :info, "There were no changes in the #{pkg.name.fg("blue")} package"
        log :info, "Build stopped (add -f to build anyway)"
      end
      version
    end

    private
    def update_from_origin(branch)
      log :info, "Pulling changes from origin"

      git_cmd = "git --git-dir #{@git_dir} rev-parse #{branch} 2>/dev/null"
      git = ShellCmd.new git_cmd, :tag => "git"

      original_rev = git.out.chomp
      original_rev = nil if original_rev == branch

      begin
        if @default_branch == branch
          git_cmd = "git --git-dir #{@git_dir} pull origin #{branch}"
          ShellCmd.new git_cmd, :tag => "git", :show_out => true
        else
          git_cmd = "git --git-dir #{@git_dir} fetch origin #{branch}:#{branch}"
          ShellCmd.new git_cmd, :tag => "git", :show_out => true
        end
      rescue Exception => e
        log :err, "Unable to pull from origin"
        raise e
      end

      git_cmd = "git --git-dir #{@git_dir} rev-parse #{branch} 2>/dev/null"
      git = ShellCmd.new git_cmd, :tag => "git"
      current_rev = git.out.chomp

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

    def get_subpackage_names(control_file)
      packages = []
      File.open control_file, "r" do |f|
        f.each_line do |l|
          if /^Package: / =~ l
            packages.push l.split(" ")[1]
          end
        end
      end

      packages
    end

    def get_architectures(control_file)
      arches = []
      File.open control_file, "r" do |f|
        f.each_line do |l|
          m = l.match /^Architecture: (.+)/
          arches += m.captures[0].chomp.split(" ") if m
        end
      end

      arches.uniq
    end
  end
end
