# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class CpioExtractor < Extractor
      handles :cpio

      def extract(target)
        reader = Omnizip::Formats::Cpio::Reader.new(@archive)
        reader.open
        reader.extract_all(target)
      end
    end
  end
end
