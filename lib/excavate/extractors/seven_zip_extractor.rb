# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class SevenZipExtractor < Extractor
      handles :seven_zip, :exe

      def extract(target)
        offset = Omnizip::Formats::SevenZip.search_embedded(@archive)

        if offset
          # Self-extracting archive - use offset
          Omnizip::Formats::SevenZip.open(@archive, offset: offset) do |reader|
            reader.extract_all(target)
          end
        else
          Omnizip::Formats::SevenZip.open(@archive) do |reader|
            reader.extract_all(target)
          end
        end
      end
    end
  end
end
