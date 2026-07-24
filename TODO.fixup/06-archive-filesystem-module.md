# 06 — Extract `Excavate::Filesystem` helper

Status: **pending**

## Why

`Excavate::Archive` currently owns four Windows-safe retry helpers
(`windows_safe_rm`, `windows_safe_rm_rf`, plus the inline
`replace_archive_with_contents` rescue logic). These are pure
filesystem operations with retry-on-`EACCES`/`ENOTEMPTY` semantics and
have nothing to do with archives. They violate MECE: the Archive class
is mixing archive orchestration with low-level FS reliability.

## Plan

Create `lib/excavate/filesystem.rb`:

```ruby
module Excavate
  module Filesystem
    module_function

    RETRYABLE_ERRORS = [Errno::EACCES, Errno::ENOTEMPTY].freeze
    DEFAULT_MAX_RETRIES = 5
    DEFAULT_RETRY_DELAY = 0.2

    def remove(path, max_retries: DEFAULT_MAX_RETRIES, delay: DEFAULT_RETRY_DELAY)
      with_retry(max_retries: max_retries, delay: delay) { FileUtils.rm(path) }
    end

    def remove_recursive(path, max_retries: DEFAULT_MAX_RETRIES, delay: DEFAULT_RETRY_DELAY)
      with_retry(max_retries: max_retries, delay: delay) { FileUtils.rm_rf(path) }
    end

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
```

Update `lib/excavate.rb` to autoload `:Filesystem,
"excavate/filesystem"`.

Update `lib/excavate/archive.rb`:

- `windows_safe_rm(path, ...)` → `Filesystem.remove(path)`
- `windows_safe_rm_rf(path, ...)` → `Filesystem.remove_recursive(path)`
- The `ensure ... FileUtils.rm_rf(target)` clauses in
  `extract_particular_files` and `extract_by_filter` should also use
  `Filesystem.remove_recursive` for consistency.
- `replace_archive_with_contents` already rescues Errno::EACCES for a
  *different* reason (Windows file lock during mv); leave it but route
  the `windows_safe_rm(archive)` call through `Filesystem.remove`.

## Acceptance

- Archive no longer has private `windows_safe_*` methods.
- New file `lib/excavate/filesystem.rb` exists with autoload.
- All archive specs still pass.
- New spec `spec/excavate/filesystem_spec.rb` covers both methods'
  happy path and retry behaviour (use a fake error class with a stub
  that fails N-1 times then succeeds).
