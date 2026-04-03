require "spec_helper"

RSpec.describe Excavate::Extractors::OleExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with msi archive" do
      let(:archive_file) { "fonts.msi" }

      it "extracts files from OLE compound document" do
        extractor.extract(target_dir)
        files = Dir.glob(File.join(target_dir, "**", "*"))
          .select { |f| File.file?(f) }

        expect(files).not_to be_empty
      end

      it "renames embedded cab files with .cab extension" do
        extractor.extract(target_dir)
        cabs = Dir.glob(File.join(target_dir, "**", "*.cab"))

        expect(cabs).not_to be_empty
      end
    end

    context "with non-ole file" do
      let(:archive_file) { "file.txt" }

      it "raises an error" do
        expect { extractor.extract(target_dir) }.to raise_error(StandardError)
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "fonts.msi" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end

    it "is registered for :ole magic type" do
      expect(Excavate::Extractors::Extractor.for_magic_type(:ole))
        .to eq(described_class)
    end
  end
end
