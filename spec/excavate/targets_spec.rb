require "spec_helper"

RSpec.describe Excavate::Targets do
  let(:work_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(work_dir)
  end

  describe ".ensure_absent" do
    it "is a no-op when the path does not exist" do
      expect do
        described_class.ensure_absent(File.join(work_dir, "missing"))
      end.not_to raise_error
    end

    it "raises TargetExistsError for an existing file" do
      path = File.join(work_dir, "victim.txt")
      FileUtils.touch(path)

      expect { described_class.ensure_absent(path) }
        .to raise_error(Excavate::TargetExistsError, /file `victim\.txt`/)
    end

    it "raises TargetExistsError for an existing directory" do
      path = File.join(work_dir, "subdir")
      FileUtils.mkdir(path)

      expect { described_class.ensure_absent(path) }
        .to raise_error(Excavate::TargetExistsError, /directory `subdir`/)
    end
  end

  describe ".ensure_empty" do
    it "is a no-op for an empty directory" do
      expect { described_class.ensure_empty(work_dir) }.not_to raise_error
    end

    it "raises TargetNotEmptyError for a non-empty directory" do
      FileUtils.touch(File.join(work_dir, "x"))
      basename = File.basename(work_dir)

      expect { described_class.ensure_empty(work_dir) }
        .to raise_error(Excavate::TargetNotEmptyError,
                        /#{Regexp.escape(basename)}/)
    end
  end

  describe ".default_for" do
    around do |example|
      Dir.chdir(work_dir) { example.run }
    end

    it "creates a directory in the cwd named after the source basename" do
      source = File.join(work_dir, "fonts.zip")
      FileUtils.touch(source)

      result = described_class.default_for(source)

      expect(File.directory?(result)).to be true
      expect(File.basename(result)).to eq("fonts")
    end

    it "refuses to overwrite an existing path" do
      source = File.join(work_dir, "fonts.zip")
      FileUtils.touch(source)
      FileUtils.mkdir(File.join(work_dir, "fonts"))

      expect { described_class.default_for(source) }
        .to raise_error(Excavate::TargetExistsError)
    end
  end
end
