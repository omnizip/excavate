require "spec_helper"

RSpec.describe Excavate::Extractors::TarExtractor do
  subject(:extractor) { described_class.new(archive) }

  let(:archive) do
    File.expand_path("../../examples/archives/#{archive_file}", __dir__)
  end

  describe "#extract" do
    let(:target_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(target_dir)
    end

    context "with tar archive" do
      let(:archive_file) { "fonts.tar" }

      it "extracts Marlett.ttf" do
        extractor.extract(target_dir)
        ttf = Dir.glob(File.join(target_dir, "**", "Marlett.ttf")).first

        expect(ttf).not_to be_nil
        expect(File.size(ttf)).to eq(26_656)
      end
    end

    context "with non-tar file" do
      let(:archive_file) { "file.txt" }

      it "extracts no files" do
        extractor.extract(target_dir)
        files = Dir.glob(File.join(target_dir, "**", "*"))
          .select { |f| File.file?(f) }

        expect(files).to be_empty
      end
    end
  end

  describe "interface" do
    let(:archive_file) { "fonts.tar" }

    it "inherits from Extractor base class" do
      expect(described_class.superclass)
        .to eq(Excavate::Extractors::Extractor)
    end

    it "is registered for :tar magic type" do
      expect(Excavate::Extractors::Extractor.for_magic_type(:tar))
        .to eq(described_class)
    end
  end
end
