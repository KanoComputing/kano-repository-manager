# Copyright (C) 2014-2017 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

require "tco"
require "thread"

tco_conf = Tco::config

tco_conf.names["green"] = "#99ad6a"
tco_conf.names["yellow"] = "#d8ad4c"
tco_conf.names["red"] = "#cc333f" #"#cf6a4c"
tco_conf.names["light-grey"] = "#ababab"
tco_conf.names["dark-grey"] = "#2b2b2b"
tco_conf.names["purple"] = "#90559e"
tco_conf.names["blue"] = "#4D9EEB" #"#1b8efa"
tco_conf.names["orange"] = "#ff842a"
tco_conf.names["brown"] = "#6a4a3c"
tco_conf.names["magenta"] = "#ff00ff"

tco_conf.styles["info"] = {
  :fg => "green",
  :bg => "dark-grey",
  :bright => false,
  :underline => false
}
tco_conf.styles["warn"] = {
  :fg => "dark-grey",
  :bg => "yellow",
  :bright => false,
  :underline => false
}
tco_conf.styles["err"] = {
  :fg => "dark-grey",
  :bg => "red",
  :bright => false,
  :underline => false
}

tco_conf.styles["debug"] = {
  :fg => "light-grey",
  :bg => "dark-grey",
  :bright => false,
  :underline => false
}

tco_conf.styles["log-head"] = {
  :fg => "purple",
  :bg => "dark-grey",
  :bright => false,
  :underline => false
}

tco_conf.styles["pkg-name"] = {
  :fg => "orange",
  :bg => "",
  :bright => false,
  :underline => false
}

tco_conf.styles["subpkg-name"] = {
  :fg => "purple",
  :bg => "",
  :bright => false,
  :underline => false
}

tco_conf.styles["version"] = {
  :fg => "brown",
  :bg => "",
  :bright => false,
  :underline => false
}

Tco::reconfigure tco_conf

module Dr
  module Logger
    @@message_types = {
      :info => "info",
      :warn => "warn",
      :err  => "err",
      :debug => "debug"
    }

    @@verbosity = :verbose
    @@logger_verbosity_levels = {
      :essential => 0,
      :important => 1,
      :informative => 2,
      :verbose => 3
    }

    @@stdout_mutex = Mutex.new
    @@log_file = nil

    def self.set_logfile(file)
      @@log_file = file
    end

    def self.set_verbosity(level)
      msg = "Message verbosity level not recognised (#{level})."
      raise msg unless @@logger_verbosity_levels.has_key? level.to_sym

      @@verbosity = level.to_sym
    end

    def self.log(msg_type, msg, verbosity=nil)
      out = "dr".style("log-head") << " "

      case msg_type
      when :info
        out << "info".style(@@message_types[:info])
        verbosity = :informative unless verbosity
      when :warn
        out << "WARN".style(@@message_types[:warn])
        verbosity = :informative unless verbosity
      when :err
        out << "ERR!".style(@@message_types[:err])
        verbosity = :essential unless verbosity
      when :debug
        out << "dbg?".style(@@message_types[:debug])
        verbosity = :verbose unless verbosity
      end

      if verbosity <= @@verbosity
        out << " " << msg.chomp

        @@stdout_mutex.synchronize do
          puts out
          STDOUT.flush

          unless @@log_file.nil?
            @@log_file.puts strip_colours out
            @@log_file.flush
          end
        end
      end
    end

    def log(msg_type, msg)
      Logger::log msg_type, msg
    end

    def tag(tag, msg)
      tag.fg("blue").bg("dark-grey") << " " << msg
    end

    private
    def self.strip_colours(string)
      string.gsub(/\033\[[0-9]+(;[0-9]+){0,2}m/, '')
    end
  end
end
