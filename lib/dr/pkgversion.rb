# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

module Dr
  class PkgVersion
    attr_accessor :upstream, :debian, :date, :build

    def initialize(version_string)
      @upstream = nil
      @debian = nil
      @date = nil
      @build = 0

      v = version_string.split "-"
      @upstream = v[0] if v.length > 0
      if v.length > 1
        dv = v[1].split "."

        @debian = dv[0] if dv.length > 0
        if dv.length > 1
          if dv[1] =~ /^[0-9]{8}/
            @date = dv[1][0..7]
          end

          match = dv[1].match /build([0-9]+)$/
          if match
            @build = match.captures[0]
          end
        end
      end
    end

    def increment!
      if @date == today
        @build += 1
      else
        @date = today
      end

      self
    end

    def <(o)
      self.to_s < o.to_s
    end

    def <=(o)
      self.to_s <= o.to_s
    end

    def ==(o)
      self.to_s == o.to_s
    end

    def to_s
      v = @upstream.clone
      if @debian
        v << "-#{@debian}"
      else
        v << "-0"
      end

      if @date
        v << ".#{@date}"
      else
        v << ".#{today}"
      end

      if @build > 0
        if @build < 10
          v << "build0#{@build}"
        else
          v << "build#{@build}"
        end
      end

      v
    end

    def source
      v = "#{upstream}"
      v << "-#{debian}" if @debian
      v
    end

    private
    def today
      Time.now.strftime "%Y%m%d"
    end
  end
end
