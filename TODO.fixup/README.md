# Excavate — Fixup TODO Inventory

This directory tracks every code-quality issue identified during the
2026-07-24 audit. Each `NN-name.md` file is a self-contained work order.

## Status legend

- **done** — work completed, specs green, rubocop clean
- **pending** — not yet started

## Work order (executed in this order)

| # | File | Priority | Status | Subject |
|---|------|----------|--------|---------|
| 01 | [01-autoload-migration.md](01-autoload-migration.md) | P1 | done | Replace every `require_relative` of internal library code with `autoload` declared in the immediate parent namespace file. |
| 02 | [02-redundant-external-requires.md](02-redundant-external-requires.md) | P3 | done | Drop the per-format `require "omnizip/formats/X"` lines (omnizip already autoloads them) and the stray staged `require "omnizip"` in cpio_extractor. |
| 03 | [03-extractor-registry-ocp.md](03-extractor-registry-ocp.md) | P1 | done | Replace `MAGIC_MAP` + `const_get` with a self-registering extractor registry so adding a format is a single `handles :type` line in the new class. |
| 04 | [04-filemagic-signature-struct.md](04-filemagic-signature-struct.md) | P2 | done | Promote the `[offset, magic, type]` tuple to a named `Signature` value object. |
| 05 | [05-utils-silence-stream-dead-code.md](05-utils-silence-stream-dead-code.md) | P2 | done | Remove the always-`File::NULL` ternary and the dead `RbConfig` branch. |
| 06 | [06-archive-filesystem-module.md](06-archive-filesystem-module.md) | P1 | done | Extract Windows-safe FS retries into `Excavate::Filesystem` so the Archive class stops mixing concerns. |
| 07 | [07-archive-targets-helper.md](07-archive-targets-helper.md) | P2 | done | Move target-path safety (existence/emptiness checks, default-target creation) into `Excavate::Targets`. |
| 08 | [08-archive-selection-dry.md](08-archive-selection-dry.md) | P2 | done | Unify `extract_particular_files` and `extract_by_filter` behind one `Selection` collaborator — current code duplicates the tmp-extract + copy scaffolding. |
| 09 | [09-cab-fallback-heuristic-named.md](09-cab-fallback-heuristic-named.md) | P2 | done | Replace inline `e.message.start_with?(...)` sniffing with a named `NestedCabFallback` predicate for testability. |
| 10 | [10-specs-remove-respond-to-matcher.md](10-specs-remove-respond-to-matcher.md) | P3 | done | Replace `respond_to(:extract)` matcher in xz_extractor_spec with the existing interface contract test (forbidden matcher). |
| 11 | [11-specs-cover-new-collaborators.md](11-specs-cover-new-collaborators.md) | P2 | done | Add specs for the new `Filesystem`, `Targets`, `Selection`, and `NestedCabFallback` collaborators introduced by 06–09. |
| 12 | [12-final-verification.md](12-final-verification.md) | P1 | done | Run full `rspec` + `rubocop` and confirm zero regressions. |

## Final verification (2026-07-24)

```
$ bundle exec rspec
210 examples, 0 failures

$ bundle exec rubocop
50 files inspected, no offenses detected

$ grep -rn "require_relative" lib/
(no hits)

$ grep -rn "respond_to\|instance_variable_set\|instance_variable_get\|double(" lib/ spec/
(no hits)

$ grep -rn "\.send(" lib/ spec/
(no hits)
```

## Summary of changes

### New collaborators (lib/excavate/)
- `filesystem.rb` — Windows-safe remove/remove_recursive with retry policy
- `targets.rb` — target-path policy (ensure_absent / ensure_empty / default_for)
- `selection.rb` — explicit-name or glob-filter matcher for selective extraction
- `nested_cab_fallback.rb` — named predicate for the EXE-may-hide-CAB heuristic

### Refactored
- `excavate.rb` — now the autoload manifest; eagerly defines the error hierarchy so rescue clauses work for downstream users
- `extractors.rb` — autoload manifest for every extractor subclass
- `extractors/extractor.rb` — registry API (`handles`, `for_magic_type`, `eager_load_subclasses!`) with shared class-variable state so subclasses register on load
- `extractors/*.rb` — every subclass now declares `handles :type` and drops the per-format external requires
- `file_magic.rb` — `Signature = Struct.new(:offset, :magic, :type)` value object; `detect_bytes` delegates to `matching_signature` helper for ABC size compliance
- `utils.rb` — dead `RbConfig` ternary removed
- `archive.rb` — uses Filesystem, Targets, Selection, NestedCabFallback collaborators; public API unchanged; `files` returns an Enumerator when no block is given

### New specs (spec/excavate/)
- `filesystem_spec.rb` — 7 examples
- `targets_spec.rb` — 6 examples
- `selection_spec.rb` — 7 examples
- `nested_cab_fallback_spec.rb` — 6 examples

### Updated
- `extractor_spec.rb` — replaced `MAGIC_MAP` static-key specs with `.registered_types` check
- `xz_extractor_spec.rb` — removed `respond_to(:extract)` matcher
- `.rubocop_todo.yml` — regenerated; obsolete entries for non-existent `test_archives/` and `test_msi_memory.rb` dropped
