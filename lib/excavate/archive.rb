# frozen_string_literal: true

module Excavate
  class Archive
    def initialize(archive)
      @archive = archive
    end

    def files(recursive_packages: false, files: [], filter: nil, &block)
      unless block
        return enum_for(:files, recursive_packages: recursive_packages,
                                files: files, filter: filter)
      end

      recursive_packages = true if files.any?

      target = Dir.mktmpdir
      extract(target, recursive_packages: recursive_packages,
                      files: files, filter: filter)

      all_files_in(target).each(&block)
    ensure
      Filesystem.remove_recursive(target) if target
    end

    def extract(target = nil,
                recursive_packages: false,
                files: [],
                filter: nil)
      recursive_packages = true if files.any?

      if files.size.positive?
        extract_selection(target, Selection.from_files(files),
                          recursive_packages: recursive_packages)
      elsif filter
        extract_selection(target, Selection.from_filter(filter),
                          recursive_packages: recursive_packages)
      else
        extract_all(target, recursive_packages: recursive_packages)
      end
    end

    private

    def extract_selection(target, selection, recursive_packages: false)
      tmp = Dir.mktmpdir
      extract_all(tmp, recursive_packages: recursive_packages)
      found = selection.match(all_files_in(tmp), tmp)
      copy_files(found, target || Dir.pwd)
    ensure
      Filesystem.remove_recursive(tmp) if tmp
    end

    def copy_files(files, target)
      FileUtils.mkdir_p(target)
      files.map do |file|
        target_path = File.join(target, File.basename(file))
        Targets.ensure_absent(target_path)

        FileUtils.cp(file, target_path)

        target_path
      end
    end

    def extract_all(target, recursive_packages: false)
      source = File.expand_path(@archive)
      target ||= Targets.create_default(source)
      Targets.ensure_empty(target)

      if recursive_packages
        extract_recursively(source, target)
      else
        extract_once(source, target)
      end

      target
    end

    def extract_recursively(archive, target)
      extract_to_directory(archive, target)

      all_files_in(target).each do |file|
        next unless archive?(file)

        extract_and_replace(file)
      end
    end

    def extract_to_directory(archive, target)
      if File.directory?(archive)
        duplicate_dir(archive, target)
      elsif !archive?(archive)
        FileUtils.cp(archive, target)
      else
        extract_once(archive, target)
      end
    end

    def duplicate_dir(source, target)
      Dir.chdir(source) do
        (Dir.entries(".") - [".", ".."]).each do |entry|
          FileUtils.cp_r(entry, target)
        end
      end
    end

    def extract_once(archive, target)
      type = FileMagic.detect(archive)
      extractor_class = Extractors::Extractor.for_magic_type(type)
      unless extractor_class
        raise UnknownArchiveError,
              "Could not unarchive `#{archive}`."
      end

      extractor_class.new(archive).extract(target)
    rescue StandardError => e
      raise unless NestedCabFallback.applies_to?(type, e)

      Extractors::CabExtractor.new(archive).extract(target)
    end

    def extract_and_replace(archive)
      target = Dir.mktmpdir
      extract_recursively(archive, target)
      Filesystem.replace_with_contents(archive, target)
    rescue StandardError
      # During recursive extraction of nested archives, silently skip
      # any that fail (e.g. .msi files that aren't real OLE, .cab files
      # with incompatible format, .exe files with unsupported compression).
      # Only re-raise if the file is not a recognized archive format.
      raise unless File.exist?(archive) && archive?(archive)
    ensure
      Filesystem.remove_recursive(target) if target
    end

    def all_files_in(dir)
      Dir.glob(File.join(dir, "**", "*"))
    end

    def archive?(file)
      return false unless File.file?(file)

      type = FileMagic.detect(file)
      !type.nil? && !Extractors::Extractor.for_magic_type(type).nil?
    end
  end
end
