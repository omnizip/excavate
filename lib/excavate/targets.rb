# frozen_string_literal: true

module Excavate
  # Target-path policy for archive extraction.
  #
  # Encapsulates the "where may I write?" decisions: refusing to
  # overwrite existing files, refusing to extract into non-empty
  # directories, and synthesising a default target directory name from
  # the archive's basename. These rules are pure path policy with no
  # archive knowledge, so they live here rather than on Archive.
  module Targets
    module_function

    # Raise TargetExistsError unless +path+ is free. Distinguishes
    # files from directories in the message for actionable diagnostics.
    def ensure_absent(path)
      return unless File.exist?(path)

      kind = File.directory?(path) ? "directory" : "file"
      raise TargetExistsError,
            "Target #{kind} `#{File.basename(path)}` already exists."
    end

    # Raise TargetNotEmptyError unless +path+ is an empty directory.
    def ensure_empty(path)
      return if Dir.empty?(path)

      raise TargetNotEmptyError,
            "Target directory `#{File.basename(path)}` is not empty."
    end

    # Build the default extraction target for +source+: a sibling
    # directory named after the archive's basename with extension
    # stripped. Refuses to clobber an existing path.
    def default_for(source)
      target = File.expand_path(File.basename(source, ".*"))
      ensure_absent(target)
      FileUtils.mkdir(target)
      target
    end
  end
end
