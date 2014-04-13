require "dr/package"
require "dr/pkgversion"
require "dr/shellcmd"

require "yaml"

module Dr
  class GitPackage < Package
    def self.setup(repo, git_addr, default_branch, force=false)
      Dir.mktmpdir do |tmp|
        git_cmd = "git clone --mirror --branch #{default_branch} " +
                  "#{git_addr} #{tmp}/git"
        ShellCmd.new git_cmd, :tag => "git", :show_out => true

        FileUtils.mkdir_p "#{tmp}/src"

        log :info, "Extracting the sources"
        git_cmd ="git --git-dir #{tmp}/git --bare archive " +
                 "--format tar #{default_branch} | tar x -C #{tmp}/src"
        ShellCmd.new git_cmd, :tag => "git", :show_out => true

        unless File.exists? "#{tmp}/src/debian/control"
          log :err, "The debian packaging files not found in the repository"
          raise "Adding a package from #{git_addr} failed"
        end

        src_name = nil
        File.open "#{tmp}/src/debian/control", "r" do |f|
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

        log :info, "Adding #{src_name.style "pkg-name"} to the repository"
        FileUtils.mkdir_p "#{pkg_dir}"

        log :info, "Setting up builds directory"
        FileUtils.mkdir_p "#{pkg_dir}/builds"

        log :info, "Setting up the source directory"
        FileUtils.mv "#{tmp}/git", "#{pkg_dir}/source"

        log :info, "The #{src_name.style "pkg-name"} package added successfully"
      end
    end

    def initialize(name, repo)
      super name, repo

      @git_dir = "#{repo.location}/packages/#{name}/source"
      @default_branch = get_current_branch
    end

    def reinitialise_repo
      git_addr = get_repo_url

      log :info, "Re-downloading the source repository of " +
                 "#{@name.style "pkg-name"}"
      Dir.mktmpdir do |tmp|
        git_cmd = "git clone --mirror --branch #{@default_branch} " +
                  "#{git_addr} #{tmp}/git"
        ShellCmd.new git_cmd, :tag => "git", :show_out => true

        src_dir = "#{tmp}/src"
        FileUtils.mkdir_p src_dir

        checkout @default_branch, src_dir

        unless File.exists? "#{tmp}/src/debian/control"
          log :err, "The debian packaging files not found in the repository"
          raise "Adding a package from #{git_addr} failed"
        end

        src_name = nil
        File.open "#{tmp}/src/debian/control", "r" do |f|
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

        unless src_name == @name
          log :err, "The name of the package in the repo has changed"
          raise "Adding a package from #{git_addr} failed"
        end

        src_dir = "#{@repo.location}/packages/#{@name}/source"
        FileUtils.rm_rf src_dir
        FileUtils.mv "#{tmp}/git", "#{src_dir}"
      end
    end

    def build(branch=nil, force=false)
      branch = @default_branch unless branch

      version = nil

      orig_rev, curr_rev = update_from_origin branch
      log :info, "Branch #{branch.fg "blue"}, revision #{curr_rev[0..7].fg "blue"}"
      unless force
        history.each do |v|
          metadata = @repo.get_build_metadata @name, v
          if metadata.has_key?("revision") && metadata["revision"] == curr_rev
            msg = "This revision of #{@name.style "pkg-name"} has already " +
                  "been built and is available as #{v.to_s.style "version"}"
            log :info, msg
            return
          end
        end
      end

      Dir.mktmpdir do |src_dir|
        checkout branch, src_dir

        version = PkgVersion.new get_version "#{src_dir}/debian/changelog"
        log :info, "Source version: #{version.source.style "version"}"

        while build_exists? version
          version.increment!
        end
        log :info, "Build version: #{version.to_s.style "version"}"

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
            log :info, "Building the #{@name.style "pkg-name"} package " +
                       "version #{version.to_s.style "version"} for #{arch}"

            # Moving to the proper directory
            build_dir_name = "#{@name}-#{version.upstream}"
            build_dir = "#{br}/#{build_dir_name}"
            FileUtils.cp_r src_dir, build_dir

            # Make orig tarball
            files = Dir["#{build_dir}/*"].map { |f| "\"#{File.basename f}\"" }.join " "
            log :info, "Creating orig source tarball"
            tar = "tar cz -C #{build_dir} --exclude=debian " +
                  "-f #{br}/#{@name}_#{version.upstream}.orig.tar.gz " +
                  "#{files}"
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

              deb_filename = File.basename(pkg)
              log :info, "Signing the #{deb_filename.style "subpkg-name"} package"
              @repo.sign_deb "#{build_dir}/#{deb_filename}"
            end

            log :info, "Writing package metadata"
            File.open "#{build_dir}/.metadata", "w" do |f|
              YAML.dump({"branch" => branch, "revision" => curr_rev}, f)
            end
            log :info, "The #{@name.style "pkg-name"} package was " +
                       "built successfully."
          end
        end
      end
      version
    end

    private
    def update_from_origin(branch)
      log :info, "Pulling changes from origin"

      original_rev = get_rev branch

      begin
        git_cmd = "git --git-dir #{@git_dir} --bare fetch origin"
        ShellCmd.new git_cmd, :tag => "git", :show_out => true
      rescue Exception => e
        log :err, "Unable to pull from origin"
        raise e
      end

      current_rev = get_rev branch

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

    def get_repo_url
      git_cmd = "git --git-dir #{@git_dir} --bare remote show origin -n"
      git = ShellCmd.new git_cmd, :tag => "git"
      git.out.lines.grep(/Fetch URL/)[0].chomp[13..-1]
    end

    def get_current_branch
      git_cmd = ShellCmd.new "git --git-dir #{@git_dir} --bare branch", {
        :tag => "git"
      }
      git_cmd.out.chomp.lines.grep(/^\*/)[0][2..-1].chomp
    end

    def get_rev(branch)
      git_cmd = "git --git-dir #{@git_dir} --bare rev-parse #{branch} 2>/dev/null"
      git = ShellCmd.new git_cmd, :tag => "git", :expect => [0, 128]

      if git.status.exitstatus == 0
        git.out.chomp
      else
        nil
      end
    end

    def checkout(branch, dir)
      log :info, "Extracting the sources"
      git_cmd ="git --git-dir #{@git_dir} --bare archive " +
               "--format tar #{branch} | tar x -C #{dir}"
      ShellCmd.new git_cmd, :tag => "git", :show_out => true
    end
  end
end
