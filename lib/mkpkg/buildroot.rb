require "tco"

require "mkpkg/logger"
require "mkpkg/shellcmd"

module Mkpkg
  class BuildRoot
    include Logger

    def initialize(br_archive=nil)
      @location = br_archive

      @extra_pkgs = "sudo,vim,ca-certificates,fakeroot,build-essential," +
                    "devscripts,debhelper,git,bc,locales,equivs,pkg-config"
      @repo = "http://mirrordirector.raspbian.org/raspbian/"

      if br_archive == nil || !File.exists?(br_archive)
        setup
      end
    end

    def open
      Dir.mktmpdir do |tmp|
        puts "Preparing the build-root ..."
        Kernel.system "sudo tar xz -C #{tmp} -f #{@location}"
        begin
          yield tmp
        ensure
          Kernel.system "sudo rm -rf #{tmp}/*"
        end
      end
    end

    private
    def setup
      Dir.mktmpdir do |tmp|
        broot = "#{tmp}/broot"
        FileUtils.mkdir_p "#{tmp}/broot"

        log :info, "Setting up the buildroot"

        begin
          log :info, "Bootstrapping Raspian (first stage)"

          cmd = "sudo debootstrap --foreign --variant=buildd --no-check-gpg " +
                "--include=#{@extra_pkgs} --arch=armhf wheezy #{broot} #{@repo}"
          debootsrap = ShellCmd.new cmd, {
            :tag => "debootstrap",
            :show_out => true
          }

          which = ShellCmd.new "which qemu-arm-static", :tag => "which"
          cp = ShellCmd.new "sudo cp #{which.out.chomp} #{broot}/usr/bin", {
            :tag => "cp"
          }

          log :info, "Bootstrapping Raspian (ARM stage)"
          cmd = "sudo chroot #{broot} /debootstrap/debootstrap --second-stage"
          debootstrap = ShellCmd.new cmd, {
            :tag => "debootstrap",
            :show_out => true
          }

          log :info, "Configuring the build root"
          cmd = "sudo chroot #{broot} <<EOF
            echo 'deb #{@repo} wheezy main contrib non-free rpi' >> /etc/apt/sources.list
            echo 'deb-src #{@repo} wheezy main contrib non-free rpi' >> /etc/apt/sources.list

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
  end
end
