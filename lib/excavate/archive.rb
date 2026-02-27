module Excavate
  class Archive
    INVALID_MEMORY_MESSAGE =
      "invalid memory read at address=0x0000000000000000".freeze

    TYPES = { "cab" => Extractors::CabExtractor,
              "cpio" => Extractors::CpioExtractor,
              "exe" => Extractors::SevenZipExtractor,
              "gz" => Extractors::GzipExtractor,
              "msi" => Extractors::OleExtractor,
              "pkg" => Extractors::XarExtractor,
              "rpm" => Extractors::RpmExtractor,
              "tar" => Extractors::TarExtractor,
              "xz" => Extractors::XzExtractor,
              "zip" => Extractors::ZipExtractor }.freeze

    def initialize(archive)
      @archive = archive
    end

    def files(recursive_packages: false, files: [], filter: nil, &block)
      # Auto-enable recursive_packages when extracting specific files
      recursive_packages = true if files.any?

      target = Dir.mktmpdir
      extract(target, recursive_packages: recursive_packages,
                      files: files, filter: filter)

      all_files_in(target).map(&block)
    ensure
      windows_safe_rm_rf(target)
    end

    def extract(target = nil,
                recursive_packages: false,
                files: [],
                filter: nil)
      # Auto-enable recursive_packages when extracting specific files
      recursive_packages = true if files.any?

      if files.size.positive?
        extract_particular_files(target, files,
                                 recursive_packages: recursive_packages)
      elsif filter
        extract_by_filter(target, filter,
                          recursive_packages: recursive_packages)
      else
        extract_all(target, recursive_packages: recursive_packages)
      end
    end

    private

    def extract_particular_files(target, files, recursive_packages: false)
      tmp = Dir.mktmpdir
      extract_all(tmp, recursive_packages: recursive_packages)
      found_files = find_files(tmp, files)
      copy_files(found_files, target || Dir.pwd)
    ensure
      FileUtils.rm_rf(tmp)
    end

    def copy_files(files, target)
      files.map do |file|
        FileUtils.mkdir_p(target)
        target_path = File.join(target, File.basename(file))
        ensure_not_exist(target_path)

        FileUtils.cp(file, target_path)

        target_path
      end
    end

    def ensure_not_exist(path)
      if File.exist?(path)
        type = File.directory?(path) ? "directory" : "file"
        raise(TargetExistsError,
              "Target #{type} `#{File.basename(path)}` already exists.")
      end
    end

    def find_files(source, files)
      all_files = all_files_in(source)

      files.map do |target_file|
        found_file = all_files.find do |source_file|
          file_matches?(source_file, target_file, source)
        end

        unless found_file
          raise(TargetNotFoundError, "File `#{target_file}` not found.")
        end

        found_file
      end
    end

    def file_matches?(source_file, target_file, source_dir)
      base_path(source_file, source_dir) == target_file
    end

    def base_path(path, prefix)
      path.sub(prefix, "").sub(/^\//, "").sub(/^\\/, "")
    end

    def extract_by_filter(target, filter, recursive_packages: false)
      tmp = Dir.mktmpdir
      extract_all(tmp, recursive_packages: recursive_packages)
      found_files = find_by_filter(tmp, filter)
      copy_files(found_files, target || Dir.pwd)
    end

    def find_by_filter(source, filter)
      all_files = all_files_in(source)

      found_files = all_files.select do |source_file|
        file_matches_filter?(source_file, filter, source)
      end

      if found_files.empty?
        raise(TargetNotFoundError, "Filter `#{filter}` matched no file.")
      end

      found_files
    end

    def file_matches_filter?(source_file, filter, source_dir)
      File.fnmatch?(filter, base_path(source_file, source_dir))
    end

    def extract_all(target, recursive_packages: false)
      source = File.expand_path(@archive)
      target ||= default_target(source)
      ensure_empty(target)

      if recursive_packages
        extract_recursively(source, target)
      else
        extract_once(source, target)
      end

      target
    end

    def ensure_empty(path)
      unless Dir.empty?(path)
        raise(TargetNotEmptyError,
              "Target directory `#{File.basename(path)}` is not empty.")
      end
    end

    def default_target(source)
      target = File.expand_path(File.basename(source, ".*"))
      ensure_not_exist(target)

      FileUtils.mkdir(target)

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
        copy_file(archive, target)
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

    def copy_file(archive, target)
      FileUtils.cp(archive, target)
    end

    def may_be_nested_cab?(extension, message)
      extension == "exe" &&
        (message.start_with?("Invalid file format",
                             "Unrecognized archive format") ||
         message.include?("Invalid .7z signature"))
    end

    def extract_once(archive, target)
      extension = normalized_extension(archive)
      extractor_class = TYPES[extension]
      unless extractor_class
        raise(UnknownArchiveError, "Could not unarchive `#{archive}`.")
      end

      extractor_class.new(archive).extract(target)
    rescue StandardError => e
      raise unless may_be_nested_cab?(extension, e.message)

      Extractors::CabExtractor.new(archive).extract(target)
    end

    def extract_and_replace(archive)
      target = Dir.mktmpdir
      extract_recursively(archive, target)
      replace_archive_with_contents(archive, target)
    rescue StandardError
      FileUtils.rm_rf(target)
      # During recursive extraction of nested archives, silently skip
      # any that fail (e.g. .msi files that aren't real OLE, .cab files
      # with incompatible format, .exe files with unsupported compression).
      # Only re-raise for file types we don't recognize as archives.
      raise unless TYPES.key?(normalized_extension(archive))
    end

    def replace_archive_with_contents(archive, target)
      windows_safe_rm(archive)
      FileUtils.mv(target, archive)
    rescue Errno::EACCES
      # Windows: file is locked. Copy extracted contents to archive location
      # and keep both the archive and extracted files
      target_dir = File.dirname(archive)
      # Copy all extracted files to the target directory
      Dir.glob(File.join(target, "**", "*")).each do |src|
        next unless File.file?(src)

        dest = File.join(target_dir, File.basename(src))
        FileUtils.cp(src, dest) unless File.exist?(dest)
      end
      # Leave the original locked archive in place
    end

    # Windows sometimes holds file locks briefly after operations.
    # This method retries file deletion with a small delay.
    def windows_safe_rm(path, max_retries: 5)
      attempts = 0
      begin
        FileUtils.rm(path)
      rescue Errno::EACCES => e
        attempts += 1
        if attempts < max_retries
          sleep(0.2)
          retry
        else
          raise e
        end
      end
    end

    # Windows-safe recursive removal
    def windows_safe_rm_rf(path, max_retries: 5)
      attempts = 0
      begin
        FileUtils.rm_rf(path)
      rescue Errno::EACCES, Errno::ENOTEMPTY => e
        attempts += 1
        if attempts < max_retries
          sleep(0.2)
          retry
        else
          raise e
        end
      end
    end

    def normalized_extension(file)
      fetch_extension(file).downcase
    end

    def fetch_extension(file)
      File.extname(filename(file)).sub(/^\./, "")
    end

    def filename(file)
      if file.respond_to?(:original_filename)
        file.original_filename
      else
        File.basename(file)
      end
    end

    def all_files_in(dir)
      Dir.glob(File.join(dir, "**", "*"))
    end

    def archive?(file)
      return false unless File.file?(file)

      ext = normalized_extension(file)
      return false if ext == "gz" && FileMagic.detect(file) != :gzip

      TYPES.key?(ext)
    end
  end
end
