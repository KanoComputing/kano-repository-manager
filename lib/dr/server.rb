# Copyright (C) 2015 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

require "rack"

module Dr
  class Server
    def initialize(port, root_route, address, archive_path)
      @port = port
      @host = address
      @dir_server = Rack::Builder.new do
        map root_route do
          run Rack::Directory.new(archive_path)
        end
      end
    end

    def start
      Rack::Handler::Thin.run(@dir_server, :Port => @port, :Host => @host)
    end
  end
end
