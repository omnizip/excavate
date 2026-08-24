# 07 — Extract `Excavate::Targets` helper (reverted)

Status: **reverted** — done in 3d96a8c, undone in 25412f1. Do not redo.

## What happened

This work order moved `Archive`'s three target-path helpers into an
`Excavate::Targets` module, in 3d96a8c. The architecture review that
followed reversed it and inlined them back as private methods on
`Archive`. `25412f1` recorded the reason:

> Targets was a three-one-liner module with one caller; the deletion
> test produced zero complexity reappearing elsewhere.

So the extraction is not pending work. It was tried, measured, and
rejected. Anyone reading this file for a plan should read it as a
closed decision instead.

## The surviving contract

Path policy lives in `lib/excavate/archive.rb` as private methods:

- `ensure_target_absent(path)` — raises `TargetExistsError` when
  `File.exist?(path) || File.symlink?(path)`. The message says "file",
  "directory", or "symlink" depending on what is there. The symlink
  check is deliberate: `File.exist?` alone follows symlinks, so a
  dangling symlink used to pass and `FileUtils.cp` would write through
  the link to its destination. That hole is now fixed — any symlink at
  the target path (dangling or not) raises `TargetExistsError`, and a
  regression spec pins it.
- `ensure_target_empty(path)` — raises `TargetNotEmptyError` when the
  path is a non-empty directory or a regular file. A missing path
  raises `Errno::ENOENT` from `Dir.empty?`, not `TargetNotEmptyError`.
- `default_target(source)` — derives the target from the archive's
  basename with the extension stripped, checks it is absent, creates
  it, and returns the absolute path.

Earlier drafts named these `ensure_absent`, `ensure_empty`, and
`default_for` / `create_default`. None of those names ship. The three
above are the real ones.

## Where it is covered

`spec/excavate/archive_spec.rb`, under "#extract" → "target path
policy". The examples drive `Archive#extract` and assert the observable
outcome — error class, message, what lands on disk, what is returned.
They do not reach into the private methods.

A mutation run over the path-policy code kills 10 of 10 mutations
through that public surface, including the file-collision and
not-empty cases the suite used to miss. Coverage did not need the
module.

## If you want to reopen this

Reversing 25412f1 needs new evidence, not a better spec. A spec that
is easier to write against a module is not an argument for the module.
Show a second caller, or a policy that grows past three one-liners.
