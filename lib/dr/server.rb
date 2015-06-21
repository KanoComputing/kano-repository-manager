# Copyright (C) 2015 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

require "rack"

module Dr
  class Server
    def initialize(port, root_route, archive_path)
      @port = port
      @route = root_route
      @archive = archive_path
    end

    def start
      dir_server = Rack::Builder.new do
        map @route do
          run Rack::Directory.new @archive_path
        end
      end

      Rack::Handler::WEBrick.run dir_server, :port => @port
    end
  end
end
