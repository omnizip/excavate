require "spec_helper"

RSpec.describe Excavate::Filesystem do
  let(:work_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(work_dir)
  end

  describe ".remove" do
    it "deletes an existing file" do
      path = File.join(work_dir, "victim.txt")
      FileUtils.touch(path)

      described_class.remove(path)

      expect(File.exist?(path)).to be false
    end

    it "raises ENOENT when the path is missing" do
      path = File.join(work_dir, "never_existed")
      expect { described_class.remove(path) }.to raise_error(Errno::ENOENT)
    end
  end

  describe ".remove_recursive" do
    it "deletes a non-empty directory tree" do
      inner = File.join(work_dir, "inner")
      FileUtils.mkdir_p(inner)
      FileUtils.touch(File.join(inner, "file.txt"))

      described_class.remove_recursive(work_dir)

      expect(File.exist?(work_dir)).to be false
    end
  end

  describe ".with_retry — retry behaviour" do
    it "succeeds on the first attempt when no error is raised" do
      calls = 0
      described_class.with_retry(max_retries: 3, delay: 0) { calls += 1 }
      expect(calls).to eq(1)
    end

    it "retries Errno::EACCES until the block succeeds" do
      attempts = 0
      described_class.with_retry(max_retries: 5, delay: 0) do
        attempts += 1
        raise Errno::EACCES, "locked" if attempts < 3
      end

      expect(attempts).to eq(3)
    end

    it "retries Errno::ENOTEMPTY" do
      attempts = 0
      described_class.with_retry(max_retries: 5, delay: 0) do
        attempts += 1
        raise Errno::ENOTEMPTY, "not empty" if attempts < 2
      end

      expect(attempts).to eq(2)
    end

    it "re-raises after exceeding max_retries" do
      allow(described_class).to receive(:sleep).and_return(nil)

      attempts = 0
      expect do
        described_class.with_retry(max_retries: 3, delay: 0) do
          attempts += 1
          raise Errno::EACCES, "locked forever"
        end
      end.to raise_error(Errno::EACCES)

      expect(attempts).to eq(3)
    end

    it "does not retry non-retryable errors" do
      attempts = 0
      expect do
        described_class.with_retry(max_retries: 5, delay: 0) do
          attempts += 1
          raise Errno::ENOENT, "not retryable"
        end
      end.to raise_error(Errno::ENOENT)

      expect(attempts).to eq(1)
    end
  end

  describe ".replace_with_contents" do
    it "moves the contents directory to the archive path" do
      archive = File.join(work_dir, "old.zip")
      FileUtils.touch(archive)
      contents = Dir.mktmpdir
      FileUtils.touch(File.join(contents, "extracted.txt"))

      described_class.replace_with_contents(archive, contents)

      expect(File.directory?(archive)).to be true
      expect(File.exist?(File.join(archive, "extracted.txt"))).to be true
    ensure
      FileUtils.rm_rf(contents)
    end

    it "degrades to scatter-copy when FileUtils.mv raises EACCES" do
      archive = File.join(work_dir, "locked.zip")
      FileUtils.touch(archive)
      contents = Dir.mktmpdir
      FileUtils.touch(File.join(contents, "extracted.txt"))

      allow(FileUtils).to receive(:mv).and_raise(Errno::EACCES, "locked")

      described_class.replace_with_contents(archive, contents)

      # Scatter-copy puts the extracted file next to the archive's parent.
      expect(File.exist?(File.join(work_dir, "extracted.txt"))).to be true
    ensure
      FileUtils.rm_rf(contents)
    end
  end
end
