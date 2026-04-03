# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class XzExtractor < Extractor
      def extract(target)
        data = Omnizip::Formats::Xz.decompress(@archive)
        extract_inner(data, target)
      end
    end
  end
end
