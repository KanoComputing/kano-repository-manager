# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "dr/version"
require "dr/repo"
require "dr/logger"

module Dr
  def self.check_dependencies(deps=[])
    ENV["PATH"].split(File::PATH_SEPARATOR).each do |path_dir|
      deps.delete_if do |dep_name|
        Dir[File.join(path_dir, dep_name)].length > 0
      end
    end

    if deps.length > 0
      Logger.log :warn, "Missing some dependencies:"
      deps.each { |dep| Logger.log :warn, "  #{dep.fg "red"}" }
    end
  end
end
