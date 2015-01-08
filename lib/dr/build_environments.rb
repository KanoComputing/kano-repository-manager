# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

module Dr
  module BuildEnvironments
    @@build_environments = {
      :kano => {
        :name =>"Kano OS",
        :arches => ["armhf"],
        :repos => {
          :raspbian => {
            :url => "http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian/",
            :key => "http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian.public.key",
            :src => true,
            :codename => "wheezy",
            :components => "main contrib non-free rpi"
          },

          :raspi_foundation => {
            :url => "http://dev.kano.me/mirrors/raspberrypi/",
            :key => "http://dev.kano.me/mirrors/raspberrypi/raspberrypi.gpg.key",
            :src => false,
            :codename => "wheezy",
            :components => "main"
          },

          :kano => {
            :url => "http://dev.kano.me/archive/",
            :key => "http://dev.kano.me/archive/repo.gpg.key",
            :src => false,
            :codename => "devel",
            :components => "main"
          }
        },
        :base_repo => :raspbian,
        :packages => []
      },

      :wheezy => {
        :name => "Debian Wheezy",
        :arches => ["x86_64"],
        :repos => {
          :wheezy => {
            :url => "http://ftp.uk.debian.org/debian/",
            :key => "https://ftp-master.debian.org/keys/archive-key-7.0.asc",
            :src => true,
            :codename => "wheezy",
            :components => "main contrib non-free"
          }
        },
        :base_repo => :wheezy,
        :packages => []
      }
    }

    def build_environments
      @@build_environments
    end

    def add_build_environment(name, benv)
      @@build_environments[name.to_sym] = benv
    end
  end
end
