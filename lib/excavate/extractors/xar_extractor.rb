# frozen_string_literal: true

require "omnizip"

module Excavate
  module Extractors
    class XarExtractor < Extractor
      handles :xar

      def extract(target)
        Omnizip::Formats::Xar.extract(@archive, target)
        rename_payload(target)
      end

      private

      def rename_payload(target)
        Dir.glob(File.join(target, "**", "Payload")).each do |file|
          next unless File.file?(file)

          FileUtils.mv(file, "#{file}.cpio.gz")
        end
      end
    end
  end
end
