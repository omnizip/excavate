# frozen_string_literal: true

require "omnizip/formats/cpio"

module Excavate
  module Extractors
    class CpioExtractor < Extractor
      def extract(target)
        reader = Omnizip::Formats::Cpio::Reader.new(@archive)
        reader.open
        reader.extract_all(target)
      end
    end
  end
end
