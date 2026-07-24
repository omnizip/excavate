# Spec-only helper: redirect +stream+ to /dev/null for the duration
# of the block, then restore it. Used by spec/cli to swallow Thor's
# stdout during command tests so the test runner output stays clean.
module SilenceStream
  def silence_stream(stream)
    previous = stream.dup
    stream.reopen(File::NULL)
    stream.sync = true
    yield
  ensure
    stream.reopen(previous)
  end
end
