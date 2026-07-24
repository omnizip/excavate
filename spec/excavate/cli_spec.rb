require "excavate/cli"

RSpec.describe Excavate::CLI do
  include SilenceStream

  describe "#extract" do
    include_context "fresh work dir"

    around do |example|
      silence_stream($stdout) do
        example.run
      end
    end

    let(:command) { described_class.start(args) }
    let(:args) { [spec_root.join("examples/archives/fonts.cab").to_s] }

    context "no command passed" do
      it "extracts anyway" do
        command
        expect(Dir.exist?("fonts")).to be true
      end

      it "prints target path" do
        expect do
          command
        end.to output("Successfully extracted to fonts/\n").to_stdout
      end
    end

    context "relative path" do
      let(:args) { ["fonts.cab"] }

      before do
        FileUtils.cp(spec_root.join("examples/archives/fonts.cab"), ".")
      end

      it "extracts anyway" do
        command
        expect(Dir.exist?("fonts")).to be true
      end
    end

    context "target exists" do
      before { FileUtils.mkdir("fonts") }

      it "returns error code 2" do
        expect(command).to be 2
      end

      it "prints error message" do
        expect do
          command
        end.to output("Target directory `fonts` already exists.\n").to_stdout
      end
    end

    context "particular file" do
      let(:args) do
        [spec_root.join("examples/archives/several_files.zip"),
         "file1"]
      end

      it "extracts the file" do
        command
        expect(File.exist?("file1")).to be true
      end

      it "prints target path" do
        expect do
          command
        end.to output("Successfully extracted to file1\n").to_stdout
      end
    end

    context "several particular files" do
      let(:args) do
        [spec_root.join("examples/archives/several_files.zip"),
         "file1",
         "file2"]
      end

      it "extracts the files" do
        command
        expect(File.exist?("file1")).to be true
        expect(File.exist?("file2")).to be true
      end

      it "prints target paths" do
        expect do
          command
        end.to output("Successfully extracted to file1, file2\n").to_stdout
      end
    end

    context "particular file is missing" do
      let(:args) do
        [spec_root.join("examples/archives/several_files.zip"),
         "missing_file"]
      end

      it "returns error code 4" do
        expect(command).to be 4
      end

      it "prints error message" do
        expect do
          command
        end.to output("File `missing_file` not found.\n").to_stdout
      end
    end

    context "filter" do
      let(:args) do
        [spec_root.join("examples/archives/several_files.zip"),
         "--filter", "*2"]
      end

      it "extracts the files" do
        command
        expect(File.exist?("file2")).to be true
      end

      it "prints target paths" do
        expect do
          command
        end.to output("Successfully extracted to file2\n").to_stdout
      end
    end
  end

  def spec_root
    Pathname.new(File.expand_path("..", __dir__))
  end
end
