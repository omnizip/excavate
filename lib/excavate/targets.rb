# frozen_string_literal: true

module Excavate
  # Target-path policy for extraction: where output is allowed to go.
  #
  # A target must either not exist yet or be an empty directory. When
  # the caller names no target, one is derived from the archive's own
  # basename.
  #
  # Distinct from Filesystem, which owns filesystem reliability and
  # surfaces errno errors. This module owns extraction policy and
  # raises Excavate domain errors for policy violations.
  module Targets
    module_function

    def ensure_absent(path)
      return unless File.exist?(path)

      kind = File.directory?(path) ? "directory" : "file"
      raise TargetExistsError,
            "Target #{kind} `#{File.basename(path)}` already exists."
    end

    # +path+ must name an existing directory. A missing path raises
    # Errno::ENOENT; a regular file is reported as a non-empty target.
    def ensure_empty(path)
      return if Dir.empty?(path)

      raise TargetNotEmptyError,
            "Target directory `#{File.basename(path)}` is not empty."
    end

    def create_default(source)
      target = File.expand_path(File.basename(source, ".*"))
      ensure_absent(target)
      FileUtils.mkdir(target)
      target
    end
  end
end
