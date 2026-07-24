# frozen_string_literal: true

module Excavate
  # Picks files from an extracted tree by either an explicit name list
  # or a glob filter. Used by Archive's selective-extraction modes
  # (extract particular files / extract by filter) to share the
  # scaffolding that lives around the matching itself.
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

    # Match +paths+ (absolute file paths produced by an extraction)
    # against this selection. +base_dir+ is the prefix to strip when
    # comparing names; matches are returned as absolute paths from
    # +paths+. Raises TargetNotFoundError when nothing matches.
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
        found = paths.find { |path| relative(path, base_dir) == target }
        raise TargetNotFoundError, "File `#{target}` not found." unless found

        found
      end
    end

    def match_filter(paths, base_dir)
      matched = paths.select do |path|
        File.fnmatch?(@filter, relative(path, base_dir))
      end
      if matched.empty?
        raise TargetNotFoundError,
              "Filter `#{@filter}` matched no file."
      end

      matched
    end

    # Strip +base_dir+ prefix and any leading slash/backslash so that
    # the result is an archive-relative path that can be compared
    # against caller-supplied names or filters.
    def relative(path, base_dir)
      path.sub(base_dir, "").delete_prefix("/").delete_prefix("\\")
    end
  end
end
