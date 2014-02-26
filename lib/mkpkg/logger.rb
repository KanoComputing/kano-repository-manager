require "tco"

tco_conf = Tco::config

tco_conf.names["green"] = "#99ad6a"
tco_conf.names["yellow"] = "#d8ad4c"
tco_conf.names["red"] = "#cf6a4c"
tco_conf.names["light-grey"] = "#ababab"
tco_conf.names["dark-grey"] = "#2b2b2b"
tco_conf.names["purple"] = "#90559e"
tco_conf.names["blue"] = "#1b8efa"

tco_conf.styles["info"] = {
  :fg => "green",
  :bg => "dark-grey",
  :bright => false,
  :underline => false
}
tco_conf.styles["warn"] = {
  :fg => "yellow",
  :bg => "dark-grey",
  :bright => false,
  :underline => false
}
tco_conf.styles["err"] = {
  :fg => "red",
  :bg => "dark-grey",
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

Tco::reconfigure tco_conf

module Mkpkg
  module Logger
    @@logger_options = {
      :info => "info",
      :warn => "warn",
      :err  => "err",
      :debug => "debug"
    }

    def self.log(level, msg)
      out = "drepo".style("log-head") << " "

      case level
      when :info  then out << "info".style(@@logger_options[:info])
      when :warn  then out << "WARN".style(@@logger_options[:warn])
      when :err   then out << "ERR!".style(@@logger_options[:err])
      when :debug then out << "dbg?".style(@@logger_options[:debug])
      end

      out << " " << msg.chomp
      puts out
      STDOUT.flush
    end

    def log(level, msg)
      Logger::log level, msg
    end

    def tag(tag, msg)
      tag.fg("blue") << " " << msg
    end
  end
end
