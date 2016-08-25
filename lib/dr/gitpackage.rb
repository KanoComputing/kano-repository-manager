# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "dr/package"
require "dr/pkgversion"
require "dr/shellcmd"
require "dr/utils"

require "yaml"
require "octokit"

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
            match = line.match(/^Source: (.+)$/)
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

      @pkg_dir = "#{repo.packages_dir}/#{name}"
      @git_dir = "#{pkg_dir}/source"
      @pkg_metadata_path = "#{@pkg_dir}/metadata"

      @default_branch = get_current_branch
    end

    def reinitialise_repo(git_addr=nil, branch=nil)
      git_addr ||= get_repo_url
      branch ||= @default_branch

      log :info, "Re-downloading the source repository of " +
                 "#{@name.style "pkg-name"}"
      Dir.mktmpdir do |tmp|
        git_cmd = "git clone --mirror --branch #{branch} " +
                  "#{git_addr} #{tmp}/git"
        ShellCmd.new git_cmd, :tag => "git", :show_out => true

        src_dir = "#{tmp}/src"
        FileUtils.mkdir_p src_dir

        checkout branch, src_dir, "#{tmp}/git"

        unless File.exists? "#{src_dir}/debian/control"
          log :err, "The debian packaging files not found in the repository"
          raise "Adding a package from #{git_addr} failed"
        end

        src_name = nil
        File.open "#{tmp}/src/debian/control", "r" do |f|
          f.each_line do |line|
            match = line.match(/^Source: (.+)$/)
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

      @default_branch = branch
    end

    def get_configuration
      if File.exists? @pkg_metadata_path
        Utils::symbolise_keys YAML.load_file @pkg_metadata_path
      else
        {}
      end
    end

    def set_configuration(config)
      # TODO: Some validation needed
      File.open(@pkg_metadata_path, "w") do |f|
        YAML.dump Utils::stringify_symbols(config), f
      end
    end

    def build(branch=nil, force=false)
      branch = @default_branch unless branch

      version = nil

      orig_rev, curr_rev = update_from_origin branch

      unless curr_rev
        log :err,  "Branch #{branch.fg "blue"} not found in #{@name.style "pkg-name"}"
        raise "The requested branch doesn't exist in the repository!"
      end

      log :info, "Branch #{branch.fg "blue"}, revision #{curr_rev[0..7].fg "blue"}"
      unless force
        history.each do |v|
          metadata = @repo.get_build_metadata @name, v
          if metadata.has_key?("revision") && metadata["revision"] == curr_rev
            msg = "This revision of #{@name.style "pkg-name"} has already " +
                  "been built and is available as #{v.to_s.style "version"}"
            log :info, msg
            return v
          end
        end
      end

      Dir.mktmpdir do |src_dir|
        checkout branch, src_dir

        version_string = get_version "#{src_dir}/debian/changelog"
        unless version_string
          log :err, "Couldn't get the version string from the changelog"
          raise "The changelog format doesn't seem be right"
        end

        version = PkgVersion.new version_string
        log :info, "Source version: #{version.source.style "version"}"

        version.add_build_tag
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
          when pkg_arches.include?("any")
            repo_arches
          when pkg_arches.include?("all")
            ["all"]
          else
            repo_arches & pkg_arches
          end

        if repo_arches.length == 0
          log :err, "#{@name.style "pkg-name"} cannot be build for any of " +
                      "the architectures supported by this repository"
          raise "Unable to build the package for this repository"
        end

        benv = :default
        src_meta = get_configuration
        if src_meta.has_key? :build_environment
          benv = src_meta[:build_environment].to_sym
        end

        arches.each do |arch|
          @repo.buildroot(arch, benv).open do |br|
            log :info, "Building the #{@name.style "pkg-name"} package " +
                       "version #{version.to_s.style "version"} for #{arch}"

            # Moving to the proper directory
            build_dir_name = "#{@name}-#{version.upstream}"
            build_dir = "#{br}/#{build_dir_name}"
            FileUtils.cp_r src_dir, build_dir

            # Make orig tarball
            all_files = Dir["#{build_dir}/*"] + Dir["#{build_dir}/.*"]
            excluded_files = ['.', '..', '.git', 'debian']
            selected_files = all_files.select { |path| !excluded_files.include?(File.basename(path)) }
            files = selected_files.map { |f| "\"#{File.basename f}\"" }.join " "
            log :info, "Creating orig source tarball"
            tar = "tar cz -C #{build_dir} " +
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
                r || ((/^#{br}\/#{subpkg_name}_#{version.to_s omit_epoch=true}/ =~ n) != nil)
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

    def tag_release(tag_name, revision, options={})
      url = get_repo_url

      log :info, "Tagging #{@name.style "pkg-name"} package for " +
                 "#{tag_name.fg "yellow"} release"

      gh_repo = case url
        when /git\@github.com\:/i then url.split(":")[1].gsub(/\.git$/, "").strip
        when /github.com\//i then url.split("/")[-2..-1].join("/").gsub(/\.git$/, "").strip
        else nil
      end

      if gh_repo == nil
        git_cmd = "git --git-dir #{@git_dir} tag #{tag}"
        git = ShellCmd.new git_cmd,
          :tag => "git",
          :show_out => false,
          :raise_on_error => false

        if git.status == 128
          log :warn, "Tag #{tag_name.fg "yellow"} already exists."
          return
        end

        git_cmd = "git --git-dir #{@git_dir} push origin --tags"
        git = ShellCmd.new git_cmd, :show_out => false

        return
      end

      title = options["title"] || "Kano OS #{tag_name}"
      summary = options["summary"] || "https://github.com/KanoComputing/peldins/wiki/Changelog-#{tag_name}"

      token = ENV["GITHUB_API_TOKEN"]
      client = Octokit::Client.new :access_token => token

      releases = client.releases gh_repo
      ri = releases.index { |r| r[:tag_name] == tag_name }

      if ri == nil
        client.create_release gh_repo, tag_name,
          :target_commitish => revision,
          :name => title,
          :body => summary
      else
        log :warn, "The #{tag_name.fg "yellow"} release exists already for #{@name.style "pkg-name"}."
      end
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

    def get_repo_url
      git_cmd = "git --git-dir #{@git_dir} config --get remote.origin.url"
      git = ShellCmd.new git_cmd, :tag => "git"
      git.out.strip
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
          m = l.match(/^Architecture: (.+)/)
          arches += m.captures[0].chomp.split(" ") if m
        end
      end

      arches.uniq
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

    def checkout(branch, dir, override_git_dir=@git_dir)
      log :info, "Extracting the sources"
      git_cmd ="git --git-dir #{override_git_dir} --bare archive " +
               "--format tar #{branch} | tar x -C #{dir}"
      ShellCmd.new git_cmd, :tag => "git", :show_out => true
    end
  end
end
