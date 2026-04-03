require "spec_helper"

RSpec.describe Excavate::FileMagic do
  let(:archives_dir) do
    File.expand_path("../examples/archives", __dir__)
  end

  describe ".detect" do
    {
      "fonts.cab" => :cab,
      "test.tar.xz" => :xz,
      "simple_test.txt.xz" => :xz,
      "fonts.tar.gz" => :gzip,
      "fonts.tar" => :tar,
      "fonts.zip" => :zip,
      "fonts.msi" => :ole,
      "archive.pkg" => :xar,
      "fonts.src.rpm" => :rpm,
      "fonts_old.cpio" => :cpio,
      "fonts_new.cpio" => :cpio,
      "test.7z" => :seven_zip,
      "fonts_7z.exe" => :exe,
      "fonts_cab.exe" => :exe,
    }.each do |filename, expected_type|
      it "detects #{filename} as #{expected_type}" do
        path = File.join(archives_dir, filename)
        expect(described_class.detect(path)).to eq(expected_type)
      end
    end

    it "returns nil for plain text files" do
      path = File.join(archives_dir, "file.txt")
      expect(described_class.detect(path)).to be_nil
    end

    it "detects by content, not extension" do
      # not_really_gzip.txt.gz has .gz extension but is plain text
      path = File.join(archives_dir, "not_really_gzip.txt.gz")
      expect(described_class.detect(path)).not_to eq(:gzip)
    end

    it "detects a renamed archive correctly" do
      # Copy a zip file to a .txt extension — magic should still detect zip
      Dir.mktmpdir do |tmp|
        src = File.join(archives_dir, "fonts.zip")
        dest = File.join(tmp, "renamed.txt")
        FileUtils.cp(src, dest)

        expect(described_class.detect(dest)).to eq(:zip)
      end
    end
  end

  describe ".detect_bytes" do
    it "returns nil for nil data" do
      expect(described_class.detect_bytes(nil)).to be_nil
    end

    it "returns nil for empty data" do
      expect(described_class.detect_bytes("")).to be_nil
    end

    it "detects cab magic bytes" do
      data = "MSCF\x00\x00\x00\x00".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:cab)
    end

    it "detects xz magic bytes" do
      data = "\xFD7zXZ\x00".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:xz)
    end

    it "detects gzip magic bytes" do
      data = "\x1F\x8B".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:gzip)
    end

    it "detects tar magic bytes at offset 257" do
      data = ("\x00".b * 257) << "ustar" << ("\x00".b * 100)
      expect(described_class.detect_bytes(data)).to eq(:tar)
    end

    it "detects 7z magic bytes" do
      data = "7z\xBC\xAF\x27\x1C".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:seven_zip)
    end

    it "detects zip magic bytes" do
      data = "PK\x03\x04".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:zip)
    end

    it "detects ole magic bytes" do
      data = "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:ole)
    end

    it "detects xar magic bytes" do
      data = "xar!".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:xar)
    end

    it "detects rpm magic bytes" do
      data = "\xED\xAB\xEE\xDB".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:rpm)
    end

    it "detects cpio old format (070707)" do
      data = "070707".b << ("\x00".b * 100)
      expect(described_class.detect_bytes(data)).to eq(:cpio)
    end

    it "detects cpio new format (070701)" do
      data = "070701".b << ("\x00".b * 100)
      expect(described_class.detect_bytes(data)).to eq(:cpio)
    end

    it "detects cpio CRC format (070702)" do
      data = "070702".b << ("\x00".b * 100)
      expect(described_class.detect_bytes(data)).to eq(:cpio)
    end

    it "detects exe (MZ) magic bytes" do
      data = "MZ".b + ("\x00" * 100)
      expect(described_class.detect_bytes(data)).to eq(:exe)
    end

    it "returns nil for unrecognized data" do
      data = "\x00\x01\x02\x03" * 100
      expect(described_class.detect_bytes(data)).to be_nil
    end

    it "returns nil for data too short for any signature" do
      expect(described_class.detect_bytes("\x00")).to be_nil
    end
  end
end
