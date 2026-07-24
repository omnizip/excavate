# 10 — Remove `respond_to` matcher from xz_extractor_spec

Status: **pending**

## Why

The global rule:

> NEVER use `respond_to?` for type checking.

The matcher form `expect(obj).to respond_to(:extract)` is the same smell —
it asserts capability by name rather than by behaviour, and the contract
is already proven by the parent-class inheritance test in the same
describe block.

## Scope

```
spec/excavate/extractors/xz_extractor_spec.rb:113
  it "responds to extract method" do
    expect(extractor).to respond_to(:extract)
  end
```

## Plan

Delete that example. The neighbouring "inherits from Extractor base
class" already proves `extract` is present (it's defined on the parent
and not private). The "accepts a target directory parameter" arity
check is similarly redundant; remove it too — these are interface
contract checks duplicated in every extractor spec, and the parent
class is the contract.

## Acceptance

- xz_extractor_spec no longer uses `respond_to`.
- grep -rn "respond_to" spec/ returns nothing.
- Remaining specs still pass.
