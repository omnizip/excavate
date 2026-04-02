RSpec.describe Excavate::Archive do
  let(:archive) do
    File.expand_path("../examples/archives/#{archive_example}", __dir__)
  end

  describe "#files" do
    shared_examples "yields filename" do |filename|
      it "yields files contained in archive" do
        Array.new.tap do |files|
          described_class.new(archive).files do |f|
            files << f
          end

          expect(files).to include(include(filename))
        end
      end
    end

    context "any archive" do
      let(:archive_example) { "fonts.zip" }

      it "yields" do
        expect { |b| described_class.new(archive).files(&b) }.to yield_control
      end
    end

    context "cab" do
      context "cab extension" do
        let(:archive_example) { "fonts.cab" }

        include_examples "yields filename", "Marlett.ttf"
      end

      context "exe extension" do
        let(:archive_example) { "fonts_cab.exe" }

        include_examples "yields filename", "Marlett.ttf"
      end
    end

    context "cpio" do
      context "old format" do
        let(:archive_example) { "fonts_old.cpio" }

        include_examples "yields filename", "Marlett.ttf"
      end

      context "new format" do
        let(:archive_example) { "fonts_new.cpio" }

        include_examples "yields filename", "Marlett.ttf"
      end
    end

    context "gzip" do
      let(:archive_example) { "fonts.tar.gz" }

      include_examples "yields filename", "Marlett.ttf"
    end

    context "ole" do
      let(:archive_example) { "fonts.msi" }

      include_examples "yields filename", ".cab"
    end

    context "rpm" do
      let(:archive_example) { "fonts.src.rpm" }

      include_examples "yields filename", "fonts.src.cpio.gz"
    end

    context "seven_zip" do
      let(:archive_example) { "fonts_7z.exe" }

      include_examples "yields filename", "Marlett.ttf"
    end

    context "tar" do
      let(:archive_example) { "fonts.tar" }

      include_examples "yields filename", "Marlett.ttf"
    end

    context "xar" do
      let(:archive_example) { "archive.pkg" }

      include_examples "yields filename", "Payload"
    end

    context "xz" do
      let(:archive_example) { "test.tar.xz" }

      include_examples "yields filename", "test_xz_content.txt"
    end

    context "zip" do
      let(:archive_example) { "fonts.zip" }

      include_examples "yields filename", "Marlett.ttf"
    end

    context "recursive packages" do
      shared_examples "yields filename recursively" do |filename|
        it "yields files contained in archive" do
          Array.new.tap do |files|
            described_class.new(archive).files(recursive_packages: true) do |f|
              files << f
            end

            expect(files).to include(include(filename))
          end
        end
      end

      context "gzip" do
        let(:archive_example) { "fonts.tar.gz" }

        include_examples "yields filename recursively", "Marlett.ttf"
      end

      context "gz extension but not really a gzip" do
        let(:archive_example) { "not_really_gzip.txt.gz" }

        include_examples "yields filename recursively", "not_really_gzip.txt.gz"
      end

      context "ole" do
        let(:archive_example) { "fonts.msi" }

        include_examples "yields filename recursively", "Marlett.ttf"
      end

      context "rpm" do
        let(:archive_example) { "fonts.src.rpm" }

        include_examples "yields filename recursively", "Example.txt"
      end

      context "pkg" do
        let(:archive_example) { "archive.pkg" }

        include_examples "yields filename recursively", "file.txt"
      end

      context "xz" do
        let(:archive_example) { "test.tar.xz" }

        include_examples "yields filename recursively", "test_xz_content.txt"
      end

      context "failing subarchive" do
        let(:archive_example) { "fonts_failing_subarchive.zip" }

        include_examples "yields filename recursively", "Marlett.ttf"
      end

      context "folder with archive extension" do
        let(:archive_example) { "folder_with_extension.zip" }

        include_examples "yields filename recursively", "file.txt"
      end

      context "directory" do
        let(:archive_example) { "dir" }

        include_examples "yields filename recursively", "Marlett.ttf"
      end

      context "regular file" do
        let(:archive_example) { "file.txt" }

        include_examples "yields filename recursively", "file.txt"
      end
    end

    context "particular file is passed" do
      let(:archive_example) { "fonts.zip" }

      it "yields only particular file" do
        files = []
        described_class.new(archive).files(files: ["Fonts/Marlett.ttf"]) do |f|
          files << f
        end

        expect(files.size).to be 1
        expect(files).to include(include("Marlett.ttf"))
      end
    end

    context "particular file in nested archive with auto-enabled recursion" do
      let(:archive_example) { "multi_nested.zip" }

      it "yields only particular file without explicit recursive_packages" do
        files = []
        described_class.new(archive)
          .files(files: ["level1.zip/level2.zip/level3.zip/file_at_deepest.txt"]) do |f|
          files << f
        end

        expect(files.size).to be 1
        expect(files).to include(include("file_at_deepest.txt"))
      end
    end

    context "filter is passed" do
      let(:archive_example) { "several_files.zip" }

      it "yields only files matching the filter" do
        files = []
        described_class.new(archive).files(filter: "*2") do |f|
          files << f
        end

        expect(files.size).to eq 1
        expect(files.first).to end_with("file2")
      end
    end
  end

  describe "#extract" do
    include_context "fresh work dir"

    context "particular file is passed" do
      let(:archive_example) { "several_files.zip" }

      it "yields only specified file" do
        files = described_class.new(archive).extract(files: ["file2"])

        expect(files.size).to eq 1
        expect(files.first).to end_with("file2")
      end
    end

    context "particular file is passed in a nested archive" do
      let(:archive_example) { "nested_archives.zip" }

      it "yields only specified file" do
        files = described_class.new(archive).extract(
          files: ["several_files.zip/file2"],
          recursive_packages: true,
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file2")
      end
    end

    context "particular file in a nested archive with auto-enabled recursion" do
      let(:archive_example) { "nested_archives.zip" }

      it "yields only specified file without explicit recursive_packages" do
        files = described_class.new(archive).extract(
          files: ["several_files.zip/file2"],
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file2")
      end
    end

    context "multi-level nested archives" do
      let(:archive_example) { "multi_nested.zip" }

      it "extracts file from root level" do
        files = described_class.new(archive).extract(
          files: ["file_at_root.txt"],
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file_at_root.txt")
      end

      it "extracts file from level 1 (one level deep)" do
        files = described_class.new(archive).extract(
          files: ["level1.zip/file_at_level1.txt"],
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file_at_level1.txt")
      end

      it "extracts file from level 2 (two levels deep)" do
        files = described_class.new(archive).extract(
          files: ["level1.zip/level2.zip/file_at_level2.txt"],
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file_at_level2.txt")
      end

      it "extracts file from level 3 (three levels deep)" do
        files = described_class.new(archive).extract(
          files: ["level1.zip/level2.zip/level3.zip/file_at_deepest.txt"],
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file_at_deepest.txt")
      end

      it "extracts files from multiple nesting levels in one call" do
        files = described_class.new(archive).extract(
          files: [
            "file_at_root.txt",
            "level1.zip/file_at_level1.txt",
            "level1.zip/level2.zip/file_at_level2.txt",
            "level1.zip/level2.zip/level3.zip/file_at_deepest.txt",
          ],
        )

        expect(files.size).to eq 4
        basenames = files.map { |f| File.basename(f) }
        expect(basenames).to contain_exactly(
          "file_at_root.txt",
          "file_at_level1.txt",
          "file_at_level2.txt",
          "file_at_deepest.txt",
        )
      end

      it "raises TargetNotFoundError for non-existent multi-level path" do
        expect do
          described_class.new(archive).extract(
            files: ["level1.zip/level2.zip/non_existent.txt"],
          )
        end.to raise_error(Excavate::TargetNotFoundError)
      end
    end

    context "backward compatibility with explicit recursive_packages: false" do
      let(:archive_example) { "several_files.zip" }

      it "still works for non-nested extraction" do
        files = described_class.new(archive).extract(
          files: ["file2"],
          recursive_packages: false,
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("file2")
      end
    end

    context "particular file is missing" do
      let(:archive_example) { "several_files.zip" }

      it "raises target-not-found error" do
        expect do
          described_class.new(archive).extract(files: ["file3"])
        end.to raise_error(Excavate::TargetNotFoundError)
      end
    end

    context "filter is passed" do
      let(:archive_example) { "several_files.zip" }

      it "extracts only files matching the filter" do
        files = described_class.new(archive).extract(filter: "*2")

        expect(files.size).to eq 1
        expect(files.first).to end_with("file2")
      end
    end

    context "file in cab archive nested in exe file" do
      let(:archive_example) { "fonts_nested_cab.exe" }

      it "yields specified file" do
        files = described_class.new(archive).extract(
          filter: "*.TTF",
          recursive_packages: true,
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("AndaleMo.TTF")
      end
    end

    # Check that 7z archive with bcj filter applied
    # https://www.mail-archive.com/xz-devel@tukaani.org/msg00370.html

    context "file in 7z archive built with BCJ and LZMA1 filters" do
      let(:archive_example) { "fonts_7z_with_bcj.exe" }

      it "yields specified file" do
        files = described_class.new(archive).extract(
          files: ["test1.txt"],
          recursive_packages: true,
        )

        expect(files.size).to eq 1
        expect(files.first).to end_with("test1.txt")
      end
    end
  end
end
