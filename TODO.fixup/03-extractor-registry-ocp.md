# 03 — Open/closed Extractor registry

Status: **pending**

## Why

`Excavate::Extractors::Extractor.for_magic_type` currently consults a frozen
`MAGIC_MAP` keyed by symbol → class-name-string and resolves via
`const_get`. Adding a new extractor requires editing this hash. That
violates OCP: the base class is open for *modification*, not just extension.

The current spec even hard-codes the expected key list
(`spec/excavate/extractors/extractor_spec.rb:6`), which means every new
extractor needs edits in three places: the new file, the parent
`extractors.rb`, and `MAGIC_MAP`. After this refactor only the new file
needs to change.

## Plan

Replace the hash + const_get with a registry pattern:

```ruby
class Extractor
  @registry = {}

  class << self
  private :inherited  # keep the hook itself private — registration is the API

  def inherited(subclass)
    super
    subclass.instance_variable_set(:@handled_types, [])
  end

  def handles(*types)
    @handled_types.concat(types)
    Extractor.register(self, types)
  end
  end

  def self.register(klass, types)
    types.each { |t| registry[t] = klass }
  end

  def self.for_magic_type(type)
    registry[type]
  end

  def self.registry
    @registry
  end
end
```

Wait — the user forbids `instance_variable_set`. Use a different shape:

```ruby
class Extractor
  @registry = {}

  class << self
    attr_reader :registry

    def handles(*types)
      types.each { |t| registry[t] = self }
    end

    def for_magic_type(type)
      registry[type]
    end

    def inherited(subclass)
      super
      subclass.instance_variable_set(:@handled_types, [])  # FORBIDDEN
    end
  end
end
```

Final design — no instance_variable_* and no const_get. Each subclass calls
`handles :cab` at class-body load time, which writes itself into the
parent's registry hash. The `inherited` hook is not needed because
registration is explicit at class definition.

```ruby
# extractors/extractor.rb
module Excavate
  module Extractors
    class Extractor
      class << self
        # Public registry API. Each subclass declares the magic types it
        # handles via `handles :type, ...` at class-body load time.
        def handles(*magic_types)
          magic_types.each { |t| registry[t] = self }
        end

        def for_magic_type(type)
          registry[type]
        end

        def registry
          @registry ||= {}
        end
      end

      def initialize(archive)
        @archive = archive
      end

      def extract(_target)
        raise NotImplementedError, "you must implement #extract"
      end

      private

      def extract_inner(data, target) ... end
      def write_raw_output(data, target) ... end
    end
  end
end
```

Each subclass:

```ruby
class CabExtractor < Extractor
  handles :cab
  ...
end

class SevenZipExtractor < Extractor
  handles :seven_zip, :exe
  ...
end
```

## Spec impact

- Remove `MAGIC_MAP` frozen spec — the registry hash is no longer public.
- Replace the per-type expectation loop with a "registered" check using
  `Extractor.for_magic_type(...)`.
- The "is registered for :type" specs in each extractor_spec.rb still pass
  unchanged because they assert via `for_magic_type`.

## Acceptance

- Adding a new format requires only: new file under
  `lib/excavate/extractors/`, new autoload entry in
  `lib/excavate/extractors.rb`, `handles :foo` in the class body.
- No edits to any other file.
- All 185 specs pass (after extractor_spec is updated to drop MAGIC_MAP).
