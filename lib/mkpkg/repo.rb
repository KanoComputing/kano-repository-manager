require "mkpkg/gitpackage"
require "mkpkg/debpackage"

require "fileutils"

module Mkpkg
  class Repo
    def initialize(loc)
      @location = loc
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

      FileUtils.mkdir_p "#{@location}/sources"
      FileUtils.mkdir_p "#{@location}/builds"
    end

    private
    def generate_gpg_key(name, email, pass)
      kill_rngd = false
      unless File.exists? "/var/run/rngd.pid"
        print "Starting rngd (root permissions required) ... "
        Kernel.system "sudo rngd -p #{@location}/rngd.pid -r /dev/urandom"
        kill_rngd = true
        puts "[OK]"
      end

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

      if kill_rngd
        print "Stopping rngd (root permissions required) ... "
        Kernel.system "sudo kill `cat #{@location}/rngd.pid`"
        Kernel.system "sudo rm -f #{@location}/rngd.pid"
        puts "[OK]"
      end

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
