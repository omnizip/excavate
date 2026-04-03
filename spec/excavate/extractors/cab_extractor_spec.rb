require "spec_helper"

RSpec.describe Excavate::Extractors::CabExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with cab archive" do
      let(:archive_file) { "fonts.cab" }

      it "extracts Marlett.ttf" do
        extractor.extract(target_dir)
        ttf = Dir.glob(File.join(target_dir, "**", "Marlett.ttf")).first

        expect(ttf).not_to be_nil
        expect(File.size(ttf)).to eq(26_656)
      end
    end

    context "with cab embedded in exe" do
      let(:archive_file) { "fonts_cab.exe" }

      it "finds embedded cab and extracts Marlett.ttf" do
        extractor.extract(target_dir)
        ttf = Dir.glob(File.join(target_dir, "**", "Marlett.ttf")).first

        expect(ttf).not_to be_nil
      end
    end

    context "with non-cab file" do
      let(:archive_file) { "file.txt" }

      it "raises an error" do
        expect { extractor.extract(target_dir) }.to raise_error(StandardError)
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "fonts.cab" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end

    it "is registered for :cab magic type" do
      expect(Excavate::Extractors::Extractor.for_magic_type(:cab))
        .to eq(described_class)
    end
  end
end
