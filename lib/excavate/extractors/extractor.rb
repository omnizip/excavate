module Excavate
  module Extractors
    class Extractor
      MAGIC_MAP = {
        cab: "CabExtractor",
        cpio: "CpioExtractor",
        exe: "SevenZipExtractor",
        gzip: "GzipExtractor",
        ole: "OleExtractor",
        rpm: "RpmExtractor",
        seven_zip: "SevenZipExtractor",
        tar: "TarExtractor",
        xar: "XarExtractor",
        xz: "XzExtractor",
        zip: "ZipExtractor",
      }.freeze

      def self.for_magic_type(type)
        name = MAGIC_MAP[type]
        Extractors.const_get(name) if name
      end

      def initialize(archive)
        @archive = archive
      end

      def extract(_target)
        raise NotImplementedError.new("You must implement this method")
      end

      private

      # Detect inner format of decompressed data and extract
      # or write raw output.
      # Shared by GzipExtractor and XzExtractor.
      def extract_inner(data, target)
        inner_type = FileMagic.detect_bytes(data)
        extractor_class = Extractor.for_magic_type(inner_type) if inner_type

        if extractor_class
          temp = File.join(target, ".temp_#{Time.now.to_i}_#{rand(1000)}")
          File.binwrite(temp, data)
          extractor_class.new(temp).extract(target)
        else
          write_raw_output(data, target)
        end
      ensure
        FileUtils.rm_f(temp) if temp
      end

      def write_raw_output(data, target)
        basename = File.basename(@archive, ".*")
        File.binwrite(File.join(target, basename), data)
      end
    end
  end
end
