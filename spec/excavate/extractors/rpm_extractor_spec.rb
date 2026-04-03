require "spec_helper"

RSpec.describe Excavate::Extractors::RpmExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with rpm archive" do
      let(:archive_file) { "fonts.src.rpm" }

      it "extracts payload with correct filename" do
        extractor.extract(target_dir)
        payload = Dir.glob(File.join(target_dir, "**", "*.cpio.gz")).first

        expect(payload).not_to be_nil
        expect(File.size(payload)).to be > 0
      end

      it "extracts payload as gzip-compressed cpio" do
        extractor.extract(target_dir)
        payload = Dir.glob(File.join(target_dir, "**", "*.cpio.gz")).first
        type = Excavate::FileMagic.detect(payload)

        expect(type).to eq(:gzip)
      end
    end

    context "with non-rpm file" do
      let(:archive_file) { "file.txt" }

      it "raises an error" do
        expect { extractor.extract(target_dir) }.to raise_error(StandardError)
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "fonts.src.rpm" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end

    it "is registered for :rpm magic type" do
      expect(Excavate::Extractors::Extractor.for_magic_type(:rpm))
        .to eq(described_class)
    end
  end
end
