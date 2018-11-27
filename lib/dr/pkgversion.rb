# Copyright (C) 2014-2018 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

module Dr
  class PkgVersion
    attr_accessor :epoch, :upstream, :debian, :date, :build

    def initialize(version_string)
      @epoch = 0       # integer
      @upstream = ""   # string
      @debian = ""     # string
      @date = 0        # integer
      @build = 0       # integer

      # Make sure the version is string
      version_string = version_string.to_s

      v = version_string.split ":"
      if v.length > 1
        @epoch = v[0].to_i
        version_string = v[1..-1].join ":"
      end

      v = version_string.split "-"
      if v.length == 1
        @upstream = version_string
      else
        @upstream = v[0...-1].join "-"

        # Check whether the is a build tag in the debian version
        dv = v[-1].split "."
        if dv.length == 1
          @debian = v[-1]
        else
          @debian = dv[0]

          build_tag = dv[1..-1].join "."

          if build_tag =~ /^[0-9]{8}/
            @date = dv[1][0..7].to_i

            match = dv[1].match(/build([0-9]+)$/)
            if match
              @build = match.captures[0].to_i
            end
          else
            # The part behind the '.' isn't a valid build tag,
            # append the string back to debian version.
            @debian << '.' << build_tag
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
      compare(o) < 0
    end

    def >(o)
      compare(o) > 0
    end

    def <=(o)
      compare(o) <= 0
    end

    def >=(o)
      compare(o) >= 0
    end

    def ==(o)
      compare(o) == 0
    end

    def <=>(o)
      compare(o)
    end

    def to_s(omit_epoch=false)
      v = @upstream.clone

      if @epoch > 0 and not omit_epoch
        v = "#{@epoch}:#{v}"
      end

      if @debian.length > 0
        v << "-#{@debian}"
      end

      if @date > 0
        v << ".#{@date}"

        if @build > 0
          v << "build#{@build}"
        end
      end

      v
    end

    def source
      v = "#{upstream}"
      v = "#{epoch}:#{v}" if @epoch > 0
      v << "-#{debian}" if @debian.length > 0
      v
    end

    def add_build_tag
        @date = today
    end

    private
    def today
      Time.now.strftime("%Y%m%d").to_i
    end

    def compare(o)
      return @epoch <=> o.epoch if @epoch != o.epoch

      result = debian_version_string_compare @upstream, o.upstream
      return result if result != 0

      result = debian_version_string_compare @debian, o.debian
      return result if result != 0

      result = @date <=> o.date
      return result if result != 0

      @build <=> o.build
    end

    # Compare two version strings (either upstream or debian versions)
    # in the Debian way
    def debian_version_string_compare(str1, str2)
      phase = :string
      while true
        return 0 if str1.length == 0 && str2.length == 0
        return -1 if str1.length == 0
        return 1 if str2.length == 0

        if phase == :digit
          part1 = str1.match(/^[0-9]*/)[0]
          str1 = str1.sub(/^[0-9]*/, "")

          part2 = str2.match(/^[0-9]*/)[0]
          str2 = str2.sub(/^[0-9]*/, "")

          result = part1.to_i <=> part2.to_i
          return result if result != 0
          phase = :string
        else
          part1 = str1.match(/^[^0-9]*/)[0]
          str1 = str1.sub(/^[^0-9]*/, "")

          part2 = str2.match(/^[^0-9]*/)[0]
          str2 = str2.sub(/^[^0-9]*/, "")

          result = debian_string_compare part1, part2
          return result if result != 0
          phase = :digit
        end
      end
    end

    # Compare two strings without any digits in the Debian way
    def debian_string_compare(str1, str2)
      return 0 if str1.length == 0 && str2.length == 0
      return -1 if str1.length == 0
      return 1 if str2.length == 0

      c1 = str1[0]
      c2 = str2[0]

      # Both characters are letters and are not equal
      #   -> compare them and return the result
      return c1 <=> c2 if is_letter(c1) && is_letter(c2) && c1 != c2

      # Both characters are non-letters and are not equal
      # We need to sort out ~ being less than everything
      if !is_letter(c1) && !is_letter(c2)
        if c1 != c2
          return -1 if c1 == '~'
          return 1 if c2 == '~'
          return c1 <=> c2
        end
      end

      # If one is a letter and one isn't, non-letter is always smaller
      return -1 if !is_letter(c1) && is_letter(c2)
      return 1 if is_letter(c1) && !is_letter(c2)

      # The characters are equal, compare the rest of the string
      return debian_string_compare str1[1..-1], str2[1..-1]
    end

    def is_letter(str)
      (str =~ /[a-z]/i) != nil
    end
  end
end
