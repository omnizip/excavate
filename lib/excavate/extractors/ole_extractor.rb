# frozen_string_literal: true

require "omnizip"
require "omnizip/formats/ole"
require_relative "../file_magic"

module Excavate
  module Extractors
    # Extractor for OLE compound documents (MSI, DOC, XLS, PPT, etc.)
    #
    # Uses Omnizip's OLE format support for extraction.
    class OleExtractor < Extractor
      def extract(target)
        do_extract(target)
        rename_archives(target)
      end

      private

      def do_extract(target)
        reset_filename_lookup

        Omnizip::Formats::Ole.open(@archive) do |ole|
          children(ole).each do |entry|
            next if ole.directory?(entry)

            path = File.join(target, prepare_filename(entry))
            FileUtils.mkdir_p(File.dirname(path))
            content = ole.read(entry)
            File.write(path, content, mode: "wb") if content
          end
        end
      end

      def children(ole)
        ole.list("/")
      end

      def reset_filename_lookup
        @file_lookup = {}
      end

      def prepare_filename(file)
        filename = sanitize_filename(file)

        @file_lookup[filename] ||= 0
        @file_lookup[filename] += 1
        filename += @file_lookup[filename].to_s if @file_lookup[filename] > 1

        filename
      end

      def sanitize_filename(filename)
        filename.strip.tap do |name|
          # NOTE: File.basename doesn't work right with Windows paths on Unix
          # get only the filename, not the whole path
          name.gsub!(/^.*(\\|\/)/, "")

          # Strip out the non-ascii character
          name.gsub!(/[^0-9A-Za-z.-]/, "_")
        end
      end

      def rename_archives(target)
        Dir.glob(File.join(target, "**", "*")).each do |file|
          next unless File.file?(file)

          FileUtils.mv(file, "#{file}.cab") if cab?(file)
        end
      end

      def cab?(file)
        FileMagic.detect(file) == :cab
      end
    end
  end
end
