# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Excavate
  class Error < StandardError; end

  class TargetExistsError < Error; end

  class TargetNotEmptyError < Error; end

  class TargetNotFoundError < Error; end

  class UnknownArchiveError < Error; end
end

module Excavate
  autoload :VERSION, "excavate/version"
  autoload :FileMagic, "excavate/file_magic"
  autoload :Filesystem, "excavate/filesystem"
  autoload :Targets, "excavate/targets"
  autoload :Selection, "excavate/selection"
  autoload :NestedCabFallback, "excavate/nested_cab_fallback"
  autoload :Extractors, "excavate/extractors"
  autoload :Archive, "excavate/archive"
  autoload :CLI, "excavate/cli"
end
