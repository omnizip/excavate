# frozen_string_literal: true

module Excavate
  # Filesystem helpers that absorb Windows file-locking quirks.
  #
  # On Windows, files and directories may be transiently locked by
  # antivirus, indexing, or other processes immediately after they are
  # written. Naive `FileUtils.rm` / `rm_rf` can raise `Errno::EACCES`
  # or `Errno::ENOTEMPTY`. These helpers retry a small number of times
  # before giving up, which is enough to ride out the brief lock
  # windows seen in CI.
  module Filesystem
    module_function

    RETRYABLE_ERRORS = [Errno::EACCES, Errno::ENOTEMPTY].freeze
    DEFAULT_MAX_RETRIES = 5
    DEFAULT_RETRY_DELAY = 0.2

    def remove(path, max_retries: DEFAULT_MAX_RETRIES,
delay: DEFAULT_RETRY_DELAY)
      with_retry(max_retries: max_retries, delay: delay) { FileUtils.rm(path) }
    end

    def remove_recursive(path, max_retries: DEFAULT_MAX_RETRIES,
delay: DEFAULT_RETRY_DELAY)
      with_retry(max_retries: max_retries, delay: delay) do
        FileUtils.rm_rf(path)
      end
    end

    # Run +block+, retrying the documented retryable errno errors up
    # to +max_retries+ times with +delay+ seconds between attempts.
    def with_retry(max_retries: DEFAULT_MAX_RETRIES, delay: DEFAULT_RETRY_DELAY)
      attempts = 0
      begin
        yield
      rescue *RETRYABLE_ERRORS => e
        attempts += 1
        raise e if attempts >= max_retries

        sleep(delay)
        retry
      end
    end
  end
end
