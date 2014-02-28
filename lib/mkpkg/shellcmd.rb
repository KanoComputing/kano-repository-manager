require "open3"
require "tco"

require "mkpkg/logger"

module Mkpkg
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
            line = tag(@tag, line) if @tag
            log(:info, line)
          end
        end

        @status = wait_thr.value
      end

      if @status.exitstatus != @expect
        out_lines = @out.split "\n"
        if out_lines.length > 10
          out_lines = out_lines[-9..-1]
        end

        out_lines.each do |l|
          l = @tag.fg("#1b8efa") + " " + l if @tag
          log(:err, l.chomp)
        end
        raise "'#{@cmd}' failed!" if @raise_on_error
      end
    end
  end
end
