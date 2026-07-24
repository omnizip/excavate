# 05 — Clean up `Utils.silence_stream` dead branch

Status: **pending**

## Why

Current implementation:

```ruby
def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(/mswin|mingw/.match?(RbConfig::CONFIG["host_os"]) ? File::NULL : File::NULL)
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end
```

Both arms of the ternary return `File::NULL`, so the OS-detection branch
is dead code. RuboCop already flags it as `Lint/DuplicateBranch` and
`Style/IdenticalConditionalBranches` in `.rubocop_todo.yml`.

Also: `RbConfig` is referenced without `require "rbconfig"`. It happens to
work because Ruby preloads it, but explicit is better.

## Plan

Two acceptable resolutions:

**Option A** — delete the ternary entirely:

```ruby
def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(File::NULL)
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end
```

**Option B** — delete the whole `Utils` module. Its only caller is
`spec/excavate/cli_spec.rb` which uses it to swallow `$stdout` during CLI
tests. That could be replaced with RSpec's `output(...).to_stdout` matcher
(which is already used elsewhere in the same file) — but the silence_stream
approach is more robust when the test doesn't care about the message body.

Choose **Option A** — keep the helper, just remove the dead code.

## Acceptance

- `Utils.silence_stream` no longer has identical branches.
- `Lint/DuplicateBranch` and `Style/IdenticalConditionalBranches` can be
  removed from `.rubocop_todo.yml`.
- cli_spec continues to silence $stdout.
