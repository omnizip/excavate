# frozen_string_literal: true

require "cabriolet"

module Excavate
  module Extractors
    class CabExtractor < Extractor
      handles :cab

      def extract(target)
        decompressor = Cabriolet::CAB::Decompressor.new
        decompressor.salvage = true # Enable salvage mode for compatibility

        # Try to find embedded CAB first (for self-extracting archives)
        cabinet = decompressor.search(@archive) || decompressor.open(@archive)
        decompressor.extract_all(cabinet, target, salvage: true)
      end
    end
  end
end
