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

    # Replace +archive_path+ with the contents of +contents_dir+,
    # absorbing Windows file-locking quirks. The optimistic path is
    # delete-then-rename; if the target file is locked we degrade to
    # copying each extracted file next to it so the user still has
    # access to the data.
    def replace_with_contents(archive_path, contents_dir)
      remove(archive_path)
      FileUtils.mv(contents_dir, archive_path)
    rescue Errno::EACCES
      scatter_contents(contents_dir, File.dirname(archive_path))
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

    # Copy each file from +source_dir+ into +destination_dir+, skipping
    # any name that already exists. The degraded fallback used when an
    # archive cannot be moved into place because it is locked.
    def scatter_contents(source_dir, destination_dir)
      Dir.glob(File.join(source_dir, "**", "*")).each do |src|
        next unless File.file?(src)

        dest = File.join(destination_dir, File.basename(src))
        FileUtils.cp(src, dest) unless File.exist?(dest)
      end
    end
  end
end
