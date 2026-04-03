require "spec_helper"

RSpec.describe Excavate::Extractors::XarExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with pkg (xar) archive" do
      let(:archive_file) { "archive.pkg" }

      it "extracts files from xar archive" do
        extractor.extract(target_dir)
        files = Dir.glob(File.join(target_dir, "**", "*"))
          .select { |f| File.file?(f) }

        expect(files).not_to be_empty
      end

      it "renames Payload files with .cpio.gz extension" do
        extractor.extract(target_dir)
        payloads = Dir.glob(File.join(target_dir, "**", "Payload.cpio.gz"))

        expect(payloads).not_to be_empty
      end
    end

    context "with non-xar file" do
      let(:archive_file) { "file.txt" }

      it "raises an error" do
        expect { extractor.extract(target_dir) }.to raise_error(StandardError)
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "archive.pkg" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end

    it "is registered for :xar magic type" do
      expect(Excavate::Extractors::Extractor.for_magic_type(:xar))
        .to eq(described_class)
    end
  end
end
