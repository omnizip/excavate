# 01 — Autoload migration

Status: **pending**

## Why

User's global rule:

> NEVER use `require_relative` for internal library code. Never use `require`
> with a path to code within your own library. Use Ruby `autoload` instead.
> Define autoload entries in the immediate parent namespace's file — create
> that file if it doesn't exist.

Currently `lib/excavate.rb` and `lib/excavate/extractors.rb` eagerly pull in
every file with `require_relative`, defeating lazy loading and creating
implicit load-order couplings.

## Scope

Offending `require_relative` calls inside `lib/`:

```
lib/excavate.rb:3  require_relative "excavate/version"
lib/excavate.rb:4  require_relative "excavate/extractors"
lib/excavate.rb:5  require_relative "excavate/archive"
lib/excavate.rb:6  require_relative "excavate/file_magic"
lib/excavate.rb:7  require_relative "excavate/utils"
lib/excavate/cli.rb:3          require_relative "../excavate"
lib/excavate/extractors.rb:1   require_relative "extractors/extractor"
lib/excavate/extractors.rb:2   require_relative "extractors/cab_extractor"
lib/excavate/extractors.rb:3   require_relative "extractors/cpio_extractor"
lib/excavate/extractors.rb:4   require_relative "extractors/gzip_extractor"
lib/excavate/extractors.rb:5   require_relative "extractors/ole_extractor"
lib/excavate/extractors.rb:6   require_relative "extractors/rpm_extractor"
lib/excavate/extractors.rb:7   require_relative "extractors/seven_zip_extractor"
lib/excavate/extractors.rb:8   require_relative "extractors/tar_extractor"
lib/excavate/extractors.rb:9   require_relative "extractors/xar_extractor"
lib/excavate/extractors.rb:10  require_relative "extractors/xz_extractor"
lib/excavate/extractors.rb:11  require_relative "extractors/zip_extractor"
lib/excavate/extractors/ole_extractor.rb:5  require_relative "../file_magic"
```

## Plan

1. `lib/excavate.rb` — the immediate-parent file for `Excavate::*`. Move
   error classes to `lib/excavate/errors.rb` and autoload it. Autoload
   `Archive`, `FileMagic`, `Utils`, `CLI`, `Extractors`. Keep
   `Excavate::VERSION` autoloaded too.
2. `lib/excavate/extractors.rb` — the immediate-parent file for
   `Excavate::Extractors::*`. Replace all 11 `require_relative` lines with
   `autoload` declarations.
3. `lib/excavate/cli.rb` — drop the `require_relative "../excavate"`. CLI is
   now autoloaded by the parent; the `thor` external require stays.
4. `lib/excavate/extractors/ole_extractor.rb` — drop the
   `require_relative "../file_magic"`. `FileMagic` is reachable via the
   autoload chain `Excavate → FileMagic`.
5. Create `lib/excavate/errors.rb` hosting the error hierarchy; have
   `excavate.rb` autoload it eagerly so exception classes are always
   defined for rescue clauses.

## Acceptance

- `grep -rn "require_relative" lib/` returns zero hits.
- `bundle exec rspec` is green.
- Loading the gem remains a single `require "excavate"` (Bundler-friendly).
