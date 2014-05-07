# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "dr/shellcmd"
require "dr/logger"

module Dr
  class GnuPG
    include Logger

    def initialize(keyring)
      @keyring = keyring

      # initialise the keyring
      FileUtils.mkdir_p @keyring
      FileUtils.chmod_R 0700, @keyring
    end

    def generate_key(name, mail, pass)
      #kill_rngd = false
      #unless File.exists? "/var/run/rngd.pid"
      #  print "Starting rngd (root permissions required) ... "
      #  Kernel.system "sudo rngd -p #{@keyring}/rngd.pid -r /dev/urandom"
      #  kill_rngd = true
      #  puts "[OK]"
      #end

      log(:info, tag("gpg", "Generating the GPG key"))

      passphrase = "Passphrase: #{pass}" if pass.length > 0
      cmd = <<-END
        gpg --batch --gen-key --homedir #{@keyring} <<EOF
        Key-Type: RSA
        Key-Length: 2048
        Subkey-Type: ELG-E
        Subkey-Length: 2048
        Name-Real: #{name}
        Name-Email: #{mail}
        #{passphrase}
        Expire-Date: 0
        %commit
EOF
END
      # TODO: Add timeout to this one
      gpg_cmd = ShellCmd.new cmd, :tag => "gpg"

      cmd = "gpg --list-keys --with-colons --homedir #{@keyring}"
      gpg_cmd = ShellCmd.new cmd, :tag => "gpg"
      key_list = gpg_cmd.out.split "\n"
      key_entry = key_list.grep(/^pub/).grep(/#{name}/).grep(/#{mail}/)
      key = key_entry[0].split(":")[4][8..-1]

      log(:info, tag("gpg", "Key done"))

      #if kill_rngd
      #  print "Stopping rngd (root permissions required) ... "
      #  Kernel.system "sudo kill `cat #{@keyring}/rngd.pid`"
      #  Kernel.system "sudo rm -f #{@keyring}/rngd.pid"
      #  puts "[OK]"
      #end

      key
    end

    def get_key_id(key)
      cmd = "gpg --homedir #{@keyring} --with-colons --list-public-keys #{key}"
      gpg = ShellCmd.new cmd, :tag => "gpg"

      gpg.out.lines.grep(/^pub/)[0].split(":")[9]
    end

    def export_pub(key, location)
      # TODO: Remove the key before exporting (so gpg doesn't ask about it)
      log(:info, tag("gpg", "Exporting key"))
      cmd = "gpg --armor --homedir #{@keyring} \
                 --output #{location} \
                 --export #{key}"
      gpg_cmd = ShellCmd.new cmd, :tag => "gpg"
    end
  end
end
