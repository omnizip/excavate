# frozen_string_literal: true

module Excavate
  module Utils
    module_function

    # Redirect +stream+ to /dev/null (File::NULL on every platform) for
    # the duration of the block, then restore it. Used by spec/cli to
    # swallow Thor's stdout during command tests.
    def silence_stream(stream)
      previous = stream.dup
      stream.reopen(File::NULL)
      stream.sync = true
      yield
    ensure
      stream.reopen(previous)
    end
  end
end
