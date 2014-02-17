require "mkpkg/gitpackage"
require "mkpkg/debpackage"

require "fileutils"

module Mkpkg
  class Repo
    def initialize(loc)
      @location = loc
    end

    def setup(conf)
      if conf[:key].is_a? Hash

        cmd = <<-END
        gpg --batch --gen-key <<EOF
        Key-Type: RSA
        Key-Length: 1024
        Name-Real: #{conf[:key][:name]}
        Name-comment: Generated at #{Time.now.to_i}
        Name-Email: #{conf[:key][:mail]}
        Expire-Date: 0
        %commit
        EOF
        END
      end

      FileUtils.mkdir_p "#{location}/conf"

      File.open "#{location}/conf", "w" do |f|
        conf[:suites].each_width_index do |s, i|
          f.puts "Suite: #{s}"

          if conf[:codenames][i].length > 0
            f.puts "Codename: #{conf[:codenames][i]}"
          end

          if conf[:name][i].length > 0
            f.puts "Origin: #{conf[:name]} - #{s}"
            f.puts "Label: #{conf[:name]} - #{s}"
          end

          if conf[:desc][i].length > 0
            f.puts "Description: #{conf[:desc]}"
          end

          f.puts "Architectures: #{conf[:arches].join " "}"
          f.puts "Components: #{conf[:components].join " "}"
        end
      end
    end
  end
end
