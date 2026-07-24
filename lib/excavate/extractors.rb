# frozen_string_literal: true

module Excavate
  module Extractors
    autoload :Extractor, "excavate/extractors/extractor"
    autoload :CabExtractor, "excavate/extractors/cab_extractor"
    autoload :CpioExtractor, "excavate/extractors/cpio_extractor"
    autoload :GzipExtractor, "excavate/extractors/gzip_extractor"
    autoload :OleExtractor, "excavate/extractors/ole_extractor"
    autoload :RpmExtractor, "excavate/extractors/rpm_extractor"
    autoload :SevenZipExtractor, "excavate/extractors/seven_zip_extractor"
    autoload :TarExtractor, "excavate/extractors/tar_extractor"
    autoload :XarExtractor, "excavate/extractors/xar_extractor"
    autoload :XzExtractor, "excavate/extractors/xz_extractor"
    autoload :ZipExtractor, "excavate/extractors/zip_extractor"
  end
end
