module Mkpkg
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

    def ==(o)
      @upstream == o.upstream && @debian == o.debian &&
      @date == o.date && @build == o.build
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

      v << "build#{@build}" if @build > 0

      v
    end

    private
    def today
      Time.now.strftime "%Y%m%d"
    end
  end
end
