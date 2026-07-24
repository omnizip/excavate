# frozen_string_literal: true

module Excavate
  module Extractors
    # Base class for all archive extractors.
    #
    # Subclasses register the magic-byte types they handle by calling
    # `handles :type, ...` at class-body load time. The base class
    # maintains the registry; new formats are added by creating a new
    # subclass file with a `handles` declaration, with no edits to this
    # file or to any branching logic.
    class Extractor
      @@registry = {}

      class << self
        # Declare which magic-byte types this extractor handles.
        # Called at class-body load time in each subclass.
        def handles(*magic_types)
          magic_types.each { |type| @@registry[type] = self }
        end

        # Resolve the extractor class for a magic-byte type, or nil if
        # no extractor is registered. Triggers eager load of all
        # extractor subclasses on first miss so every `handles`
        # declaration has had a chance to fire.
        def for_magic_type(type)
          return @@registry[type] if @@registry.key?(type)

          eager_load_subclasses!
          @@registry[type]
        end

        # The full type → class registry. Exposed for introspection
        # (specs, debugging). Not for mutation.
        def registry
          @@registry
        end

        def registered_types
          @@registry.keys
        end

        # Force-load every autoloaded constant under Extractors so that
        # each subclass's `handles` declaration runs. Idempotent.
        def eager_load_subclasses!
          Extractors.constants.each { |name| Extractors.const_get(name) }
        end
      end

      def initialize(archive)
        @archive = archive
      end

      def extract(_target)
        raise NotImplementedError, "you must implement #extract"
      end

      private

      # Detect inner format of decompressed data and extract it
      # recursively, or write raw output when no extractor matches.
      # Shared by GzipExtractor and XzExtractor.
      def extract_inner(data, target)
        inner_type = FileMagic.detect_bytes(data)
        extractor_class = self.class.for_magic_type(inner_type) if inner_type

        if extractor_class
          temp = File.join(target, ".temp_#{Time.now.to_i}_#{rand(1000)}")
          File.binwrite(temp, data)
          extractor_class.new(temp).extract(target)
        else
          write_raw_output(data, target)
        end
      ensure
        FileUtils.rm_f(temp) if temp
      end

      def write_raw_output(data, target)
        basename = File.basename(@archive, ".*")
        File.binwrite(File.join(target, basename), data)
      end
    end
  end
end
