# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "tco"

require "dr/logger"
require "dr/shellcmd"
require "dr/config"

module Dr
  class BuildRoot
    include Logger

    def initialize(env, arch, br_cache)
      @arch = arch
      if arch == "all"
        unless Dr::config.build_environments.has_key? env
          log :err, "Unkown build environment: #{env.to_s.fg "red"}"
          raise "Build environment not recognised"
        end
        @arch = Dr::config.build_environments[env][:arches][0]
      end

      @location = "#{br_cache}/#{env.to_s}-#{@arch}.tar.gz"
      @env = env

      @essential_pkgs = "sudo,vim,ca-certificates,fakeroot,build-essential," +
                        "curl,devscripts,debhelper,git,bc,locales,equivs," +
                        "pkg-config,libfile-fcntllock-perl"

      unless File.exists?(@location)
        setup @env, @arch
      end
    end

    def open
      Dir.mktmpdir do |tmp|
        log :info, "Preparing #{@env.to_s.fg "blue"} #{@arch.fg "orange"} build root"
        log :info, "Sysroot #{@location}"
        ShellCmd.new "sudo tar xz -C #{tmp} -f #{@location}", :tag => "tar"
        begin
          log :info, "Mounting the /proc file system"
          mnt_cmd = "sudo chroot #{tmp} mount -t proc none /proc"
          ShellCmd.new mnt_cmd, :tag => "mount"

          log :info, "Mounting /dev/urandom"
          touch_cmd = "sudo touch #{tmp}/dev/urandom"
          ShellCmd.new touch_cmd, :tag => "touch"
          mnt2_cmd = "sudo mount --bind /dev/urandom #{tmp}/dev/urandom"
          ShellCmd.new mnt2_cmd, :tag => "mount2"

          keys_cmd = "sudo cp -r ~/.ssh #{tmp}/root/"
          ShellCmd.new keys_cmd, :tag => "SSH keys copy"

          yield tmp
        ensure
          log :info, "Unmounting the /proc file system"
          umnt_cmd = "sudo chroot #{tmp} umount -f /proc"
          ShellCmd.new umnt_cmd, :tag => "umount"

          log :info, "Unmounting the /dev/urandom "
          umnt2_cmd = "sudo umount -f #{tmp}/dev/urandom"
          ShellCmd.new umnt2_cmd, :tag => "umount"

          log :info, "Cleaning up the buildroot"
          ShellCmd.new "sudo rm -rf #{tmp}/*", :tag => "rm"
        end
      end
    end

    private
    def setup(env, arch)
      unless Dr.config.build_environments.has_key? env
        raise "Sorry, build environment #{env.to_s.fg "blue"} isn't supported by dr."
      end

      unless Dr.config.build_environments[env][:arches].include? arch
        raise "Arch #{arch.fg "blue"} not supported by this build environment."
      end

      repos = Dr.config.build_environments[env][:repos]

      Dir.mktmpdir do |tmp|
        broot = "#{tmp}/broot"
        FileUtils.mkdir_p "#{tmp}/broot"

        log :info, "Setting up the buildroot"

        begin
          arch_cmd = ShellCmd.new "arch"
          arch = arch_cmd.out.strip

          if @arch == arch
            setup_native broot
          else
            setup_foreign broot
          end

          log :info, "Configuring the build root"

          repo_setup_sequences = repos.map do |name, repo|
            seq = "echo 'deb #{repo[:url]} #{repo[:codename]} " +
                  "#{repo[:components]}' >> /etc/apt/sources.list\n"

            if repo.has_key?(:src) && repo[:src]
              seq += "echo 'deb-src #{repo[:url]} #{repo[:codename]} " +
                     "#{repo[:components]}' >> /etc/apt/sources.list\n"
            end

            if repo.has_key?(:key) && repo[:key]
              seq += "curl --retry 5 '#{repo[:key]}' | apt-key add -\n"
            end

            seq
          end

          cmd = "sudo chroot #{broot} <<EOF
            #{repo_setup_sequences.join "\n\n"}

            echo 'en_US.UTF-8 UTF-8' >/etc/locale.gen
            locale-gen en_US.UTF-8

            cat >>/etc/bash.bashrc <<EOF2
              export LANG=en_US.UTF-8
              export LC_TYPE=en_US.UTF-8
              export LC_ALL=en_US.UTF-8
              export LANGUAGE=en_US.UTF8
EOF2
EOF"
          cfg = ShellCmd.new cmd, :tag => "chroot"

          log :info, "Updating package lists"
          update = ShellCmd.new "sudo chroot #{broot} apt-get update", {
            :tag => "chroot",
            :show_out => true
          }

          # TODO: is this necessary?
          #Kernel.system "sudo chroot #{broot} useradd -m -s /bin/bash raspbian"

          log :info, "Creating the build root archive"
          cmd = "sudo tar cz -C #{broot} -f #{@location} `ls -1 #{broot}`"
          tar = ShellCmd.new cmd, :tag => "tar"
        ensure
          log :info, "Cleaning up"
          ShellCmd.new "sudo rm -rf #{broot}", :tag => "rm"
        end
      end
    end

    def setup_foreign(broot)
      repos = Dr.config.build_environments[@env][:repos]
      base_repo = Dr.config.build_environments[@env][:base_repo].to_sym
      additional_pkgs = Dr.config.build_environments[@env][:packages].join ","
      codename = repos[base_repo][:codename]
      url = repos[base_repo][:url]

      log :info, "Bootstrapping #{@env.to_s} (foreign chroot, first stage)"
      cmd = "sudo debootstrap --foreign --variant=buildd --no-check-gpg " +
            "--include=#{@essential_pkgs},#{additional_pkgs} " +
            "--arch=#{@arch} #{codename} #{broot} #{url}"
      debootsrap = ShellCmd.new cmd, {
        :tag => "debootstrap",
        :show_out => true
      }

      static_qemu = Dir["/usr/bin/qemu-*-static"]
      static_qemu.each do |path|
        cp = ShellCmd.new "sudo cp #{path} #{broot}/usr/bin", {
          :tag => "cp"
        }
      end

      log :info, "Bootstrapping Raspian (#{@arch} stage)"
      cmd = "sudo chroot #{broot} /debootstrap/debootstrap --second-stage"
      debootstrap = ShellCmd.new cmd, {
        :tag => "debootstrap",
        :show_out => true
      }
    end

    def setup_native(broot)
      repos = Dr.config.build_environments[@env][:repos]
      base_repo = Dr.config.build_environments[@env][:base_repo].to_sym
      additional_pkgs = Dr.config.build_environments[@env][:packages].join ","
      codename = repos[base_repo][:codename]
      url = repos[base_repo][:url]

      log :info, "Bootstrapping #{@env.to_s} (native chroot)"
      cmd = "sudo debootstrap --variant=buildd --no-check-gpg " +
            "--include=#{@essential_pkgs},#{additional_pkgs} " +
            "#{codename} #{broot} #{repos[base_repo][:url]}"
      debootsrap = ShellCmd.new cmd, {
        :tag => "debootstrap",
        :show_out => true
      }
    end
  end
end
