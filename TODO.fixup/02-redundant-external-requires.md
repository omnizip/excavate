# 02 — Drop redundant external requires

Status: **pending**

## Why

`omnizip` itself uses `autoload` for every `Formats::*` constant (see
`omnizip/formats.rb`). The per-format `require "omnizip/formats/cpio"` (and
siblings) in our extractors are redundant — they re-trigger the same autoload
resolution.

Additionally the currently-staged (uncommitted) change to
`cpio_extractor.rb` adds a second external require line:
`require "omnizip"` followed by `require "omnizip/formats/cpio"`. Only one is
needed.

## Scope

Files with redundant per-format requires:

```
lib/excavate/extractors/cpio_extractor.rb:3-4  require "omnizip" / require "omnizip/formats/cpio"
lib/excavate/extractors/ole_extractor.rb:3-4   require "omnizip" / require "omnizip/formats/ole"
lib/excavate/extractors/rpm_extractor.rb:3-4   require "omnizip" / require "omnizip/formats/rpm"
lib/excavate/extractors/xar_extractor.rb:3-4   require "omnizip" / require "omnizip/formats/xar"
lib/excavate/extractors/seven_zip_extractor.rb:3  require "omnizip"
lib/excavate/extractors/tar_extractor.rb:3        require "omnizip"
lib/excavate/extractors/xz_extractor.rb:3         require "omnizip"
lib/excavate/extractors/zip_extractor.rb:3        require "omnizip"
```

## Plan

Keep one `require "omnizip"` per file that touches an Omnizip constant.
Delete the per-format `require "omnizip/formats/X"` lines — the autoload in
`omnizip/formats.rb` resolves them on first reference. The staged
`require "omnizip"` addition in cpio_extractor.rb becomes the single
omnizip require for that file (replacing the redundant format require).

For extractors that only touch a single Omnizip format constant, the
`require "omnizip"` line is also technically unneeded if any other loaded
file already requires omnizip — but keeping it makes each file
independently loadable, which is good practice. Keep them.

## Acceptance

- No `require "omnizip/formats/..."` remains in `lib/`.
- `bundle exec rspec` is green.
