# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class TarExtractor < Extractor
      def extract(target)
        reader = Omnizip::Formats::Tar::Reader.open(@archive)
        reader.extract_all(target)
      end
    end
  end
end
