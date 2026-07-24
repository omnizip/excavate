# 07 — Extract `Excavate::Targets` helper

Status: **pending**

## Why

`Excavate::Archive` owns three target-path safety helpers
(`ensure_not_exist`, `ensure_empty`, `default_target`). They are pure
path policy with no archive context — they belong in a focused value
object so they can be tested in isolation and reused.

## Plan

Create `lib/excavate/targets.rb`:

```ruby
module Excavate
  module Targets
    module_function

    def ensure_absent(path)
      return unless File.exist?(path)

      kind = File.directory?(path) ? "directory" : "file"
      raise TargetExistsError,
            "Target #{kind} `#{File.basename(path)}` already exists."
    end

    def ensure_empty(path)
      return if Dir.empty?(path)

      raise TargetNotEmptyError,
            "Target directory `#{File.basename(path)}` is not empty."
    end

    def default_for(source)
      target = File.expand_path(File.basename(source, ".*"))
      ensure_absent(target)
      FileUtils.mkdir(target)
      target
    end
  end
end
```

Update `lib/excavate.rb` to autoload `:Targets, "excavate/targets"`.

Update `lib/excavate/archive.rb`:

- `ensure_not_exist(path)` → `Targets.ensure_absent(path)`
- `ensure_empty(path)` → `Targets.ensure_empty(path)`
- `default_target(source)` → `Targets.default_for(source)`

Remove the now-empty private helpers.

## Acceptance

- Archive no longer has private target-safety methods.
- New file `lib/excavate/targets.rb` with autoload.
- New spec `spec/excavate/targets_spec.rb` covers all three methods
  including the error paths.
- Existing archive + cli specs still pass.
