# Copyright (C) 2014-2019 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

module Dr
  module BuildEnvironments
    @@build_environments = {
      :kano => {
        :name =>"Kano OS (Wheezy)",
        :arches => ["armhf"],
        :repos => {
          :raspbian => {
            :url => "http://www.mirrorservice.org/sites/archive.raspbian.org/raspbian/",
            :key => "http://www.mirrorservice.org/sites/archive.raspbian.org/raspbian.public.key",
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

      :kano_stretch => {
        :name =>"Kano OS (Stretch)",
        :arches => ["armhf"],
        :repos => {
          :stretch_bootstrap => {
            # This is used to debootstrap the system which suffers from the
            # problem that S3 doesn't like serving URLs with `+` in the path
            # so use the proxied version of:
            #     staging.stretch.raspbian.repo.os.kano.me
            :url => "http://build.os.kano.me/",
            :key => "http://build.os.kano.me/raspbian.public.key",
            :src => true,
            :codename => "stretch",
            :components => "main contrib non-free rpi",
            :build_only => true
          },
          :raspbian_stretch => {
            :url => "http://staging.stretch.raspbian.repo.os.kano.me/",
            :key => "http://staging.stretch.raspbian.repo.os.kano.me/raspbian.public.key",
            :src => true,
            :codename => "stretch",
            :components => "main contrib non-free rpi"
          },

          :raspi_foundation_stretch => {
            :url => "http://dev.kano.me/raspberrypi-stretch/",
            :key => "http://dev.kano.me/raspberrypi-stretch/raspberrypi.gpg.key",
            :src => false,
            :codename => "stretch",
            :components => "main"
          },

          :kano_stretch => {
            :url => "http://dev.kano.me/archive-stretch/",
            :key => "http://dev.kano.me/archive-stretch/repo.gpg.key",
            :src => false,
            :codename => "devel",
            :components => "main"
          }
        },
        :base_repo => :stretch_bootstrap,
        :packages => []
      },

      :kano_jessie => {
        :name =>"Kano OS (Jessie)",
        :arches => ["armhf"],
        :repos => {
          :raspbian_jessie => {
            :url => "http://staging.jessie.raspbian.repo.os.kano.me/",
            :key => "http://staging.jessie.raspbian.repo.os.kano.me/raspbian.public.key",
            :src => true,
            :codename => "jessie",
            :components => "main contrib non-free rpi"
          },

          :raspi_foundation_jessie => {
            :url => "http://dev.kano.me/raspberrypi-jessie/",
            :key => "http://dev.kano.me/raspberrypi-jessie/raspberrypi.gpg.key",
            :src => false,
            :codename => "jessie",
            :components => "main"
          },

          :kano_jessie => {
            :url => "http://dev.kano.me/archive-jessie/",
            :key => "http://dev.kano.me/archive-jessie/repo.gpg.key",
            :src => false,
            :codename => "devel",
            :components => "main"
          }
        },
        :base_repo => :raspbian_jessie,
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
      },

      :jessie => {
        :name => "Debian Jessie",
        :arches => ["x86_64"],
        :repos => {
          :wheezy => {
            :url => "http://ftp.uk.debian.org/debian/",
            :key => "https://ftp-master.debian.org/keys/archive-key-8.asc",
            :src => true,
            :codename => "jessie",
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
