# Copyright (C) 2014-2018 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

require "open3"
require "tco"

require "dr/logger"

module Dr
  class ShellCmd
    attr_reader :status, :out, :err

    include Logger

    def initialize(cmd, opts={})
      @out = ""

      @show_out = false
      @raise_on_error = true
      @tag = "shell"
      @expect = 0

      opts.each do |k, v|
        self.instance_variable_set("@#{k.to_s}", v)
      end

      @cmd = cmd
      @status = nil

      run
    end

    private
    def run
      Open3.popen2e(@cmd) do |stdin, stdouterr, wait_thr|
        pid = wait_thr.pid

        begin
          stdouterr.fsync = true
          stdouterr.sync = true
        rescue
          a = 1 # FIXME
        end

        while line = stdouterr.gets
          @out += line
          if @show_out
            line = tag(@tag.dup, line) if @tag
            log(:info, line)
          end
        end

        wait_thr.join
        @status = wait_thr.value
      end

      if (@expect.is_a?(Array) && !@expect.include?(@status.exitstatus)) ||
         (@expect.is_a?(Integer) && @status.exitstatus != @expect)
        out_lines = @out.split "\n"
        if out_lines.length > 10
          out_lines = out_lines[-10..-1]
        end

        out_lines.each do |l|
          l = tag(@tag, l.fg("red")) if @tag
          log(:err, l.chomp)
        end
        raise "'#{@cmd}' failed!".fg("red") if @raise_on_error
      end
    end
  end
end
