# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2


module Dr
  module BuildEnv
    @@build_environments = {
      "Kano OS" => {
        :arches => ["armhf", "armel"],
        :repos => {
          :raspbian => {
            :url => "http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian/",
            :key => "http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian.public.key",
            :src => true,
            :codename => "wheezy",
            :components => "main contrib non-free rpi"
          },

          :raspi_foundation => {
            :url => "http://archive.raspberrypi.org/debian/",
            :key => "http://archive.raspberrypi.org/debian/raspberrypi.gpg.key",
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
      }
    }

    def build_environments
      @@build_environments
    end

    def add_build_environment(name, benv)
      @@build_environments[name] = benv
    end
  end
end
