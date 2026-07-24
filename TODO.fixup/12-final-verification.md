# 12 — Final verification

Status: **pending**

## Why

The previous 11 tasks change a lot of files. Confirm nothing regressed.

## Plan

1. `bundle exec rspec` — expect 0 failures.
2. `bundle exec rubocop` — expect 0 new offences; wherever possible,
   drop the now-obsolete entries from `.rubocop_todo.yml`.
3. `grep -rn "require_relative" lib/` — expect zero hits.
4. `grep -rn "respond_to\|instance_variable_set\|instance_variable_get\|double(" lib/ spec/` — expect zero hits (matcher `respond_to` only in spec, now also gone).
5. `grep -rn "\.send(" lib/ spec/` — expect zero hits (no private-method bypass).

## Acceptance

All checks pass.
