require "tco"

require "dr/logger"
require "dr/shellcmd"

module Dr
  class BuildRoot
    include Logger

    def initialize(arch, br_archive=nil)
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
        log :info, "Preparing the build root"
        ShellCmd.new "sudo tar xz -C #{tmp} -f #{@location}", :tag => "tar"
        begin
          yield tmp
        ensure
          log :info, "Cleaning up the buildroot"
          ShellCmd.new "sudo rm -rf #{tmp}/*", :tag => "rm"
        end
      end
    end

    private
    def setup(arch)
      Dir.mktmpdir do |tmp|
        broot = "#{tmp}/broot"
        FileUtils.mkdir_p "#{tmp}/broot"

        log :info, "Setting up the buildroot"

        begin
          log :info, "Bootstrapping Raspian (first stage)"

          cmd = "sudo debootstrap --foreign --variant=buildd --no-check-gpg " +
                "--include=#{@extra_pkgs} --arch=#{arch} wheezy #{broot} #{@repo}"
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

          log :info, "Bootstrapping Raspian (#{arch} stage)"
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
