# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class TarExtractor < Extractor
      def extract(target)
        reader = Omnizip::Formats::Tar::Reader.open(@archive)
        reader.extract_all(target)
      ensure
        reader&.close
      end
    end
  end
end
