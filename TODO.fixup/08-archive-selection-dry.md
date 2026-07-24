# 08 — DRY up Archive selective extraction

Status: **pending**

## Why

`Archive#extract_particular_files` and `Archive#extract_by_filter` are
near-duplicates:

```ruby
def extract_particular_files(target, files, recursive_packages: false)
  tmp = Dir.mktmpdir
  extract_all(tmp, recursive_packages: recursive_packages)
  found_files = find_files(tmp, files)
  copy_files(found_files, target || Dir.pwd)
ensure
  FileUtils.rm_rf(tmp)
end

def extract_by_filter(target, filter, recursive_packages: false)
  tmp = Dir.mktmpdir
  extract_all(tmp, recursive_packages: recursive_packages)
  found_files = find_by_filter(tmp, filter)
  copy_files(found_files, target || Dir.pwd)
ensure
  FileUtils.rm_rf(tmp)
end
```

Same scaffolding (mktmpdir → extract_all → find → copy → rm_rf). The only
difference is the matching strategy. DRY violation.

The matching logic itself is also split across `find_files`, `find_by_filter`,
`file_matches?`, `file_matches_filter?`, and `base_path`. Five private
methods where one focused collaborator would do.

## Plan

Introduce `Excavate::Selection` — a small value object that knows how to
match files against either an explicit list or a glob filter.

```ruby
module Excavate
  class Selection
    def self.from_files(names)
      new(file_names: names)
    end

    def self.from_filter(pattern)
      new(filter: pattern)
    end

    def initialize(file_names: nil, filter: nil)
      @file_names = file_names
      @filter = filter
    end

    def match(paths, base_dir)
      if @file_names
        match_explicit(paths, base_dir)
      else
        match_filter(paths, base_dir)
      end
    end

    private

    def match_explicit(paths, base_dir)
      @file_names.map do |target|
        found = paths.find { |p| relative(p, base_dir) == target }
        raise TargetNotFoundError, "File `#{target}` not found." unless found

        found
      end
    end

    def match_filter(paths, base_dir)
      matched = paths.select { |p| File.fnmatch?(@filter, relative(p, base_dir)) }
      raise TargetNotFoundError, "Filter `#{@filter}` matched no file." if matched.empty?

      matched
    end

    def relative(path, base_dir)
      path.sub(base_dir, "").sub(%r{^/}, "").sub(/^\\/, "")
    end
  end
end
```

Update `lib/excavate.rb` to autoload `:Selection, "excavate/selection"`.

Update `Archive`:

```ruby
def extract(target = nil, recursive_packages: false, files: [], filter: nil)
  recursive_packages = true if files.any?

  if files.size.positive?
    extract_selection(target, Selection.from_files(files), recursive_packages: recursive_packages)
  elsif filter
    extract_selection(target, Selection.from_filter(filter), recursive_packages: recursive_packages)
  else
    extract_all(target, recursive_packages: recursive_packages)
  end
end

private

def extract_selection(target, selection, recursive_packages: false)
  tmp = Dir.mktmpdir
  extract_all(tmp, recursive_packages: recursive_packages)
  found = selection.match(all_files_in(tmp), tmp)
  copy_files(found, target || Dir.pwd)
ensure
  Filesystem.remove_recursive(tmp)
end
```

Removes: `extract_particular_files`, `extract_by_filter`, `find_files`,
`find_by_filter`, `file_matches?`, `file_matches_filter?`, `base_path`.
That's seven private methods collapsing to one collaborator + one
orchestrator method.

The `files` public method's auto-recursion logic stays the same — the
public API is unchanged.

## Acceptance

- All archive_spec examples pass without modification.
- New spec `spec/excavate/selection_spec.rb` covers both selection
  modes and the not-found error path.
- Archive private method count drops materially.
