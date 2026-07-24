require "spec_helper"

RSpec.describe Excavate::Extractors::Extractor do
  describe ".registered_types" do
    it "includes all expected magic types" do
      expected_types = %i[cab cpio exe gzip ole rpm seven_zip tar xar xz zip]
      # Force every subclass to load so registration has fired.
      described_class.for_magic_type(:cab)
      expect(described_class.registered_types).to include(*expected_types)
    end
  end

  describe ".for_magic_type" do
    {
      cab: Excavate::Extractors::CabExtractor,
      cpio: Excavate::Extractors::CpioExtractor,
      exe: Excavate::Extractors::SevenZipExtractor,
      gzip: Excavate::Extractors::GzipExtractor,
      ole: Excavate::Extractors::OleExtractor,
      rpm: Excavate::Extractors::RpmExtractor,
      seven_zip: Excavate::Extractors::SevenZipExtractor,
      tar: Excavate::Extractors::TarExtractor,
      xar: Excavate::Extractors::XarExtractor,
      xz: Excavate::Extractors::XzExtractor,
      zip: Excavate::Extractors::ZipExtractor,
    }.each do |type, expected_class|
      it "returns #{expected_class.name.split('::').last} for :#{type}" do
        expect(described_class.for_magic_type(type)).to eq(expected_class)
      end
    end

    it "returns nil for unknown type" do
      expect(described_class.for_magic_type(:unknown)).to be_nil
    end

    it "returns nil for nil type" do
      expect(described_class.for_magic_type(nil)).to be_nil
    end
  end

  describe "#extract" do
    it "raises NotImplementedError" do
      extractor = described_class.new("/fake/path")
      expect { extractor.extract("/tmp") }.to raise_error(NotImplementedError)
    end
  end

  describe "magic detection drives correct extraction" do
    let(:archives_dir) do
      File.expand_path("../../examples/archives", __dir__)
    end

    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    {
      "fonts.cab" => "Marlett.ttf",
      "fonts.tar" => "Marlett.ttf",
      "fonts.zip" => "Marlett.ttf",
      "fonts_old.cpio" => "Marlett.ttf",
      "fonts_new.cpio" => "Marlett.ttf",
      "fonts.tar.gz" => "Marlett.ttf",
      "test.tar.xz" => "test_xz_content.txt",
      "simple_test.txt.xz" => "simple_test.txt",
      "test.7z" => "test_7z_content.txt",
      "fonts.msi" => ".cab",
      "archive.pkg" => "Payload",
      "fonts.src.rpm" => "fonts.src.cpio.gz",
    }.each do |archive_file, expected_file|
      it "resolves extractor for #{archive_file}" do
        path = File.join(archives_dir, archive_file)
        type = Excavate::FileMagic.detect(path)

        expect(described_class.for_magic_type(type)).not_to be_nil
      end

      it "extracts #{expected_file} from #{archive_file}" do
        path = File.join(archives_dir, archive_file)
        type = Excavate::FileMagic.detect(path)
        klass = described_class.for_magic_type(type)
        klass.new(path).extract(target_dir)
        files = Dir.glob(File.join(target_dir, "**", "*"))
          .select { |f| File.file?(f) }
        matched = files.select { |f| f.include?(expected_file) }

        expect(matched).not_to be_empty
        expect(File.size(matched.first)).to be > 0
      end
    end

    context "with exe archives via Archive (cab fallback)" do
      include_context "fresh work dir"

      it "extracts Marlett.ttf from 7z exe" do
        path = File.join(archives_dir, "fonts_7z.exe")
        files = []
        Excavate::Archive.new(path).files { |f| files << f }

        expect(files.any? { |f| f.include?("Marlett.ttf") }).to be true
      end

      it "extracts Marlett.ttf from cab exe" do
        path = File.join(archives_dir, "fonts_cab.exe")
        files = []
        Excavate::Archive.new(path).files { |f| files << f }

        expect(files.any? { |f| f.include?("Marlett.ttf") }).to be true
      end
    end
  end
end
