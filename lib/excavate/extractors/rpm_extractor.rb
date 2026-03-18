# frozen_string_literal: true

require "omnizip"
require "omnizip/formats/rpm"

module Excavate
  module Extractors
    # Extractor for RPM packages
    #
    # Uses Omnizip's RPM format support for extraction.
    # Extracts the raw payload as a file (e.g., fonts.src.cpio.gz).
    class RpmExtractor < Extractor
      def extract(target)
        rpm = Omnizip::Formats::Rpm::Reader.new(@archive)
        rpm.open
        content = rpm.raw_payload
        path = target_path(@archive, rpm, target)

        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content, mode: "wb")
      ensure
        rpm&.close
      end

      private

      def target_path(archive, rpm, dir)
        basename = File.basename(archive, ".*")
        payload_format = rpm.tags[:payloadformat] || "cpio"
        compression_format = rpm.tags[:payloadcompressor] || "gzip"
        # Convert "gzip" to "gz" for file extension
        compression_ext = compression_format == "gzip" ? "gz" : compression_format
        filename = "#{basename}.#{payload_format}.#{compression_ext}"
        File.join(dir, filename)
      end
    end
  end
end
