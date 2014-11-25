# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2


module Dr
  class Debugger < Thor
    class << self
      attr_accessor :repo, :pkg
    end

    desc "exit", "Close the debugging console"
    def exit
    end

    desc "build", "Build the package"
    def build
    end

    desc "commit", "Commit any changes made"
    def commit
    end

    desc "terminal", "Get shell access to the build environment"
    def terminal
    end

    desc "diff", "Check any changes that were made"
    def diff
    end
  end
end
