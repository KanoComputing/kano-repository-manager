# Copyright (C) 2017 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPLv2


require "thread"

def thread_pool(items, worker_count=8)
  work_queue = Queue.new
  items.each { |item| work_queue.push item }

  threads = (0 .. worker_count).map do
    Thread.new do
      begin
        # Passing `true` causes the queue to raise an exception if it is empty
        # rather than block, waiting for something to add to it.
        while item = work_queue.pop(true)
          yield item
        end
      rescue ThreadError
        # The work_queue is empty, we are done
      end
    end
  end

  threads.map(&:join)
end
