# frozen_string_literal: true

require "zlib"

module Excavate
  module Extractors
    class GzipExtractor < Extractor
      def extract(target)
        data = Zlib::GzipReader.open(@archive, &:read)
        extract_inner(data, target)
      end
    end
  end
end
