require "thor"

module Excavate
  class CLI < Thor
    STATUS_SUCCESS = 0
    STATUS_UNKNOWN_ERROR = 1
    STATUS_TARGET_EXISTS = 2
    STATUS_TARGET_NOT_EMPTY = 3
    STATUS_TARGET_NOT_FOUND = 4

    ERROR_TO_STATUS = {
      TargetExistsError => STATUS_TARGET_EXISTS,
      TargetNotEmptyError => STATUS_TARGET_NOT_EMPTY,
      TargetNotFoundError => STATUS_TARGET_NOT_FOUND,
    }.freeze

    def self.exit_on_failure?
      false
    end

    def self.start(given_args = ARGV, config = {})
      args = if all_commands.key?(given_args[0])
               given_args
             else
               given_args.dup.unshift("extract")
             end

      super(args, config)
    end

    desc "extract ARCHIVE [FILE...]",
         "Extract FILE or all files from ARCHIVE to a new directory"
    option :recursive, aliases: :r, type: :boolean, default: false,
                       desc: "Also extract all nested archives."
    option :filter, type: :string,
                    desc: "Filter by pattern (supports **, *, ?, etc)"
    def extract(archive, *files)
      target = Excavate::Archive.new(archive).extract(
        recursive_packages: options[:recursive],
        files: files,
        filter: options[:filter],
      )

      success("Successfully extracted to #{format_paths(target)}")
    rescue Error => e
      handle_error(e)
    end
    default_task :extract

    private

    def success(message)
      say(message)
      STATUS_SUCCESS
    end

    def handle_error(exception)
      status = ERROR_TO_STATUS[exception.class]
      raise exception unless status

      error(exception.message, status)
    end

    def error(message, status)
      say(message, :red)
      status
    end

    def format_paths(path_or_paths)
      paths = Array(path_or_paths).map do |x|
        File.directory?(x) ? "#{File.basename(x)}/" : File.basename(x)
      end

      paths.join(", ")
    end
  end
end
