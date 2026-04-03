require "spec_helper"

RSpec.describe Excavate::Extractors::SevenZipExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with pure .7z archive" do
      let(:archive_file) { "test.7z" }

      it "extracts the expected file" do
        extractor.extract(target_dir)
        extracted = Dir.glob(File.join(target_dir, "**", "test_7z_content.txt"))

        expect(extracted).not_to be_empty
      end

      it "extracts file with correct content" do
        extractor.extract(target_dir)
        content = File.read(
          Dir.glob(File.join(target_dir, "**", "test_7z_content.txt")).first,
        )

        expect(content).to include("Test content for 7z archive")
      end
    end

    context "with self-extracting 7z exe" do
      let(:archive_file) { "fonts_7z.exe" }

      it "finds embedded 7z data" do
        offset = Omnizip::Formats::SevenZip.search_embedded(archive)

        expect(offset).not_to be_nil
      end
    end

    context "with non-7z file" do
      let(:archive_file) { "file.txt" }

      it "raises an error" do
        expect { extractor.extract(target_dir) }.to raise_error(StandardError)
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "test.7z" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end

    it "is registered for both :seven_zip and :exe magic types" do
      extractor_class = Excavate::Extractors::Extractor
      expect(extractor_class.for_magic_type(:seven_zip)).to eq(described_class)
      expect(extractor_class.for_magic_type(:exe)).to eq(described_class)
    end
  end
end
