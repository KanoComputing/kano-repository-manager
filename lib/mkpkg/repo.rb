require "mkpkg/gitpackage"
require "mkpkg/debpackage"

require "fileutils"

module Mkpkg
  class Repo
    attr_reader :location

    def initialize(loc)
      @location = File.realpath loc
      @br_archive = "#{@location}/build-root.tar.gz"
    end

    # TODO: Error checking, fool-proofing
    def setup(conf)
      FileUtils.mkdir_p "#{@location}/archive/conf"

      key = generate_gpg_key conf[:gpg_name], conf[:gpg_mail], conf[:gpg_pass]
      export_gpg_pub_key key

      File.open "#{@location}/archive/conf/distributions", "w" do |f|
        conf[:suites].each_with_index do |s, i|
          f.puts "Suite: #{s}"

          if conf[:codenames][i].length > 0
            f.puts "Codename: #{conf[:codenames][i]}"
          end

          if conf[:name][i].length > 0
            f.puts "Origin: #{conf[:name]} - #{s}"
            f.puts "Label: #{conf[:name]} - #{s}"
          end

          if conf[:desc].length > 0
            f.puts "Description: #{conf[:desc]}"
          end

          f.puts "Architectures: #{conf[:arches].join " "}"
          f.puts "Components: #{conf[:components].join " "}"

          f.puts "SignWith: #{key}"
          f.puts ""
        end
      end

      FileUtils.mkdir_p "#{@location}/packages"

      Dir.mktmpdir do |tmp|
        extra_pkgs = "sudo,vim,ca-certificates,fakeroot,build-essential,devscripts,debhelper,git,bc,locales,equivs,pkg-config"
        repo = "http://mirrordirector.raspbian.org/raspbian/"

        broot = "#{tmp}/broot"
        FileUtils.mkdir_p "#{tmp}/broot"

        begin
          puts "Bootstrapping Raspian (first stage)"
          Kernel.system "sudo debootstrap --foreign --variant=buildd --no-check-gpg \
           --include=#{extra_pkgs} --arch=armhf wheezy #{broot} #{repo}"

          qemu_path = `which qemu-arm-static`.chomp
          `sudo cp #{qemu_path} #{broot}/usr/bin`

          puts "Bootstrapping Raspian (ARM stage)"
          Kernel.system "sudo chroot #{broot} /debootstrap/debootstrap --second-stage"

          puts "Basic customization: raspbian repositories and regular user account"
          Kernel.system "sudo chroot #{broot} <<EOF
           echo 'deb http://mirrordirector.raspbian.org/raspbian wheezy main contrib non-free rpi' >> /etc/apt/sources.list
           echo 'deb-src http://mirrordirector.raspbian.org/raspbian wheezy main contrib non-free rpi' >> /etc/apt/sources.list

           echo 'en_US.UTF-8 UTF-8' >/etc/locale.gen
           locale-gen en_US.UTF-8

           cat >>/etc/bash.bashrc <<EOF2
             export LANG=en_US.UTF-8
             export LC_TYPE=en_US.UTF-8
             export LC_ALL=en_US.UTF-8
             export LANGUAGE=en_US.UTF8
EOF2
EOF"

          Kernel.system "sudo chroot #{broot} apt-get update"
          Kernel.system "sudo chroot #{broot} useradd -m -s /bin/bash raspbian"

          Kernel.system "sudo tar cz -C #{broot} -f #{@br_archive} `ls -1 #{broot}`"
        ensure
          Kernel.system "sudo rm -rf #{broot}"
        end
      end
    end

    def list_packages
      pkgs = []
      Dir.foreach "#{@location}/packages" do |pkg_name|
        pkgs.push get_package pkg_name unless pkg_name =~ /^\./
      end

      pkgs
    end

    def get_package(name)
      unless File.exists? "#{@location}/packages/#{name}"
        raise "Package '#{name}' doesn't exist in the repo."
      end

      if File.exists? "#{@location}/packages/#{name}/source"
        GitPackage.new name, self
      else
        DebPackage.new name, self
      end
    end

    def get_suites
      suites = nil
      File.open "#{@location}/archive/conf/distributions", "r" do |f|
        suites = f.read.split "\n\n"
      end

      suites.map do |s|
        suite = nil
        codename = nil
        s.each_line do |l|
          m = l.match /^Suite: (.+)/
          suite = m.captures[0].chomp if m

          m = l.match /^Codename: (.+)/
          codename = m.captures[0].chomp if m
        end
        [suite, codename]
      end
    end

    def query_for_version(suite, pkg_name)
      v = `reprepro --basedir #{location}/archive --list-format '${version}' list #{suite} #{pkg_name} 2>/dev/null`.chomp
      v = nil unless v.length > 0
      v
    end

    def push(pkg_name, version, suite, force=false)
      pkg = get_package pkg_name

      if version
        unless pkg.build_exists? version
          raise "Build version '#{version}' not found."
        end
      else
        raise "No #{pkg_name} build found found." if pkg.history.length == 0
        version = pkg.history[0]
      end

      if suite
        cmp = get_suites.map { |n, cn| suite == n || suite == cn }
        suite_exists = cmp.inject(false) { |r, o| r || o }
        raise "Suite '#{suite}' doesn't exist." unless suite_exists
      else
        # FIXME: This should be configurable
        suite = "testing"
      end

      current_version = query_for_version suite, pkg.name

      if current_version != nil && current_version >= version
        if force
          Kernel.system "reprepro -b #{@location}/archive --gnupghome #{location}/gnupg-keyring/ removesrc #{suite} #{pkg.name}"
        else
          raise "The same package of a higher version (#{version}) is " +
                "already in the repo."
        end
      end

      debs = Dir["#{@location}/packages/#{pkg.name}/builds/#{version}/*"]
      Kernel.system "reprepro -b #{@location}/archive --gnupghome #{location}/gnupg-keyring/ includedeb #{suite} #{debs.join " "}"
    end

    def unpush(pkg_name, suite)
      pkg = get_package pkg_name

      cmp = get_suites.map { |n, cn| suite == n || suite == cn }
      suite_exists = cmp.inject(false) { |r, o| r || o }
      raise "Suite '#{suite}' doesn't exist." unless suite_exists

      version = query_for_version pkg_name, suite

      if version
        Kernel.system "reprepro -b #{@location}/archive --gnupghome #{location}/gnupg-keyring/ removesrc #{suite} #{pkg.name}"
      else
        raise "Package #{pkg_name} is not included in #{suite}."
      end
    end

    def remove(pkg_name, force=false)
      pkg = get_package pkg_name

      versions = get_suites.map { |n, cn| query_for_version pkg_name, n }
      used = versions.inject(false) { |r, v| r || true if v != nil }
      p versions
      p used

      if used
        raise "The '#{pkg_name}' package is still used." unless force

        get_suites.zip(versions).each do |suite, version|
          unpush pkg_name, suite[0] if version != nil
        end
      end

      if !used || force
        p "Would remove!"
        #FileUtils.rm_rf "#{location}/packages/#{pkg_name}"
      end
    end

    def buildroot
      Dir.mktmpdir do |tmp|
        puts "Setting up the build-root ..."
        Kernel.system "sudo tar xz -C #{tmp} -f #{@br_archive}"
        begin
          yield tmp
        ensure
          Kernel.system "sudo rm -rf #{tmp}/*"
        end
      end
    end

    private
    def generate_gpg_key(name, email, pass)
      #kill_rngd = false
      #unless File.exists? "/var/run/rngd.pid"
      #  print "Starting rngd (root permissions required) ... "
      #  Kernel.system "sudo rngd -p #{@location}/rngd.pid -r /dev/urandom"
      #  kill_rngd = true
      #  puts "[OK]"
      #end

      FileUtils.mkdir_p "#{@location}/gnupg-keyring"
      FileUtils.chmod_R 0700, "#{@location}/gnupg-keyring"

      print "Generating the GPG key ... "
      passphrase = "Passphrase: #{pass}" if pass.length > 0
      gpg_cmd = <<-END
        gpg --batch --gen-key --homedir #{@location}/gnupg-keyring/ <<EOF
        Key-Type: RSA
        Key-Length: 2048
        Subkey-Type: ELG-E
        Subkey-Length: 2048
        Name-Real: #{name}
        Name-Email: #{email}
        #{passphrase}
        Expire-Date: 0
        %commit
EOF
      END

      Kernel.system gpg_cmd

      key_list = `gpg --list-keys --with-colons --homedir #{@location}/gnupg-keyring`.split "\n"
      key_entry = key_list.grep(/^pub/).grep(/#{name}/).grep(/#{email}/)
      key = key_entry[0].split(":")[4][8..-1]
      puts "[OK]"

      #if kill_rngd
      #  print "Stopping rngd (root permissions required) ... "
      #  Kernel.system "sudo kill `cat #{@location}/rngd.pid`"
      #  Kernel.system "sudo rm -f #{@location}/rngd.pid"
      #  puts "[OK]"
      #end

      key
    end

    def export_gpg_pub_key(key)
      print "Exporting GPG key ... "
      `gpg --armor --homedir #{@location}/gnupg-keyring \
       --output #{@location}/archive/repo.gpg.key \
       --export #{key}`
      puts "[OK]"
    end
  end
end
