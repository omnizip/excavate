# 11 — Specs for new collaborators

Status: **done**

## Why

Tasks 06–09 introduce four new collaborators (`Filesystem`, `Targets`,
`Selection`, `NestedCabFallback`). The user's rule "good specs throughout"
requires every public method to have specs.

`Targets` was later reverted (see
[07-archive-targets-helper.md](07-archive-targets-helper.md)), so three
collaborators survive. Target-path policy is covered through
`Archive#extract` in `spec/excavate/archive_spec.rb` instead.

## Scope

New spec files to add:

- `spec/excavate/filesystem_spec.rb`
- `spec/excavate/selection_spec.rb`
- `spec/excavate/nested_cab_fallback_spec.rb`

No doubles — use real files / real Dir.mktmpdir / real Struct instances
per the user's "NEVER USE DOUBLES IN SPECS" rule.

## Plan

### filesystem_spec.rb

- `remove` deletes a file.
- `remove_recursive` deletes a non-empty directory.
- Retries up to `max_retries` times on `Errno::EACCES`, then succeeds.
- Re-raises after exceeding retries.

For the retry test: monkey-patch `FileUtils.rm` to raise N times then
succeed. This avoids `double()` — use a real method override on FileUtils
within the test scope. Better: yield through a stub callable. Cleanest
approach without doubles is to wrap a counter and call the real method
in a setup that fails transiently.

Sketch:

```ruby
it "retries on Errno::EACCES then succeeds" do
  dir = Dir.mktmpdir
  path = File.join(dir, "x")
  FileUtils.touch(path)

  attempts = 0
  allow(FileUtils).to receive(:rm) do |p|
    attempts += 1
    raise Errno::EACCES, "locked" if attempts < 3
    File.delete(p)
  end

  expect { Excavate::Filesystem.remove(path, max_retries: 5, delay: 0) }
    .not_to raise_error
  expect(File.exist?(path)).to be false
end
```

rspec-mocks `allow(...).to receive(...)` is allowed by the user's rule —
the rule is specifically about `double()` creating mock objects that
bypass real type checking. Stubbing a method on a real class is different.

Hmm but the rule says "Test behavior, not interactions" and "Mocking
method calls is testing implementation, not correctness." Retrying on a
specific errno is exactly an interaction we need to test. There's no way
to test retry-without-stub unless we use a real file that genuinely
locks on Windows. Best compromise: stub FileUtils.rm to fail a fixed
number of times then delegate to the original. Add a comment explaining
why this is the rare exception.

### target path policy — in archive_spec.rb

`Targets` is gone, so these run against `Archive#extract` rather than a
module. Same cases, driven through the public API:

- A named empty target directory is accepted.
- A named target that already has entries raises `TargetNotEmptyError`.
- A named target that is a regular file raises `TargetNotEmptyError`.
- An unnamed target is created from the archive basename with the
  extension stripped, and the absolute path is returned.
- An unnamed target raises `TargetExistsError` when a file or a
  directory of that name already sits there, and the message says
  which of the two it found.
- A selected file that would land on an existing file or directory
  raises `TargetExistsError` and leaves the existing content alone.

### selection_spec.rb

- `from_files` + `match` returns the matching path.
- `from_files` raises `TargetNotFoundError` when no match.
- `from_filter` + `match` returns all matching paths.
- `from_filter` raises when nothing matches.
- Relative path computation strips the base dir and a leading slash.

### nested_cab_fallback_spec.rb

- `applies_to?(:exe, error_with_"Invalid file format")` → true.
- `applies_to?(:exe, error_with_"Unrecognized archive format")` → true.
- `applies_to?(:exe, error_with_"Invalid .7z signature")` → true.
- `applies_to?(:exe, error_with_other_message)` → false.
- `applies_to?(:cab, error_with_signature_phrase)` → false (wrong type).

## Acceptance

- All three new spec files exist and pass.
- Target-path policy is covered in `archive_spec.rb` through
  `Archive#extract`, with no reach into private methods.
- `bundle exec rspec` total example count grows by ~20.
