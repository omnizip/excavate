require "spec_helper"

RSpec.describe Excavate::Extractors::GzipExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with tar.gz archive" do
      let(:archive_file) { "fonts.tar.gz" }

      it "detects inner tar and extracts Marlett.ttf" do
        extractor.extract(target_dir)
        ttf = Dir.glob(File.join(target_dir, "**", "Marlett.ttf")).first

        expect(ttf).not_to be_nil
        expect(File.size(ttf)).to eq(26_656)
      end

      it "produces a valid TTF file" do
        extractor.extract(target_dir)
        ttf = Dir.glob(File.join(target_dir, "**", "Marlett.ttf")).first
        header = File.binread(ttf, 4)

        expect(header).to eq("\x00\x01\x00\x00".b)
      end
    end

    context "with non-gzip file having .gz extension" do
      let(:archive_file) { "not_really_gzip.txt.gz" }

      it "raises an error" do
        expect { extractor.extract(target_dir) }.to raise_error(StandardError)
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "fonts.tar.gz" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end
  end
end
