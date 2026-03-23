# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class ZipExtractor < Extractor
      def extract(target)
        reader = Omnizip::Formats::Zip::Reader.new(@archive)
        reader.read
        reader.extract_all(target)
      end
    end
  end
end
