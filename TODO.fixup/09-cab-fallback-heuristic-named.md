# 09 — Name the nested-CAB fallback heuristic

Status: **pending**

## Why

`Archive#extract_once` rescues `StandardError` and inspects the message:

```ruby
rescue StandardError => e
  raise unless type == :exe && may_be_nested_cab?(e.message)

  Extractors::CabExtractor.new(archive).extract(target)
```

with:

```ruby
def may_be_nested_cab?(message)
  message.start_with?("Invalid file format",
                       "Unrecognized archive format") ||
    message.include?("Invalid .7z signature")
end
```

Two problems:

1. The intent ("if this is an EXE that hides a CAB, retry as CAB") is
   buried inside `extract_once`.
2. The matcher is untested and undocumented magic.

Naming the predicate makes the intent obvious and gives us a place to
attach tests and documentation.

## Plan

Create `lib/excavate/nested_cab_fallback.rb`:

```ruby
module Excavate
  # Decides whether a failed extraction of a `:exe`-typed archive should be
  # retried as a CAB. Some self-extracting EXEs produced by older Microsoft
  # toolchains wrap a CAB rather than a 7z payload, and the 7z reader
  # surfaces distinctive error strings when it can't parse them.
  class NestedCabFallback
    SIGNATURE_PHRASES = [
      /Invalid file format/,
      /Unrecognized archive format/,
      /Invalid .7z signature/,
    ].freeze

    def self.applies_to?(type, error)
      type == :exe && matches_phrase?(error.message)
    end

    def self.matches_phrase?(message)
      SIGNATURE_PHRASES.any? { |re| re.match?(message) }
    end
  end
end
```

Update `lib/excavate.rb` to autoload `:NestedCabFallback,
"excavate/nested_cab_fallback"`.

Update `Archive#extract_once`:

```ruby
def extract_once(archive, target)
  type = FileMagic.detect(archive)
  extractor_class = Extractors::Extractor.for_magic_type(type)
  raise UnknownArchiveError, "Could not unarchive `#{archive}`." unless extractor_class

  extractor_class.new(archive).extract(target)
rescue StandardError => e
  raise unless NestedCabFallback.applies_to?(type, e)

  Extractors::CabExtractor.new(archive).extract(target)
end
```

Removes `may_be_nested_cab?` from Archive.

## Acceptance

- `fonts_cab.exe` / `fonts_nested_cab.exe` tests still pass.
- New spec `spec/excavate/nested_cab_fallback_spec.rb` covers
  `applies_to?` for each phrase and the negative cases.
