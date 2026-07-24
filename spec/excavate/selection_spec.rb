require "spec_helper"

RSpec.describe Excavate::Selection do
  let(:base_dir) { "/tmp/excavate_base" }

  def abs(name)
    File.join(base_dir, name)
  end

  describe ".from_files + #match" do
    it "returns the matching absolute path for each requested name" do
      paths = [abs("a.txt"), abs("b.txt"), abs("c.txt")]
      selection = described_class.from_files(["b.txt", "a.txt"])

      expect(selection.match(paths,
                             base_dir)).to eq([abs("b.txt"), abs("a.txt")])
    end

    it "matches a nested relative path" do
      paths = [abs("dir/inner.txt")]
      selection = described_class.from_files(["dir/inner.txt"])

      expect(selection.match(paths, base_dir)).to eq([abs("dir/inner.txt")])
    end

    it "raises TargetNotFoundError when any requested name is missing" do
      paths = [abs("a.txt")]
      selection = described_class.from_files(["a.txt", "missing.txt"])

      expect { selection.match(paths, base_dir) }
        .to raise_error(Excavate::TargetNotFoundError, /missing\.txt/)
    end

    it "raises TargetNotFoundError when paths is empty" do
      selection = described_class.from_files(["anything"])

      expect { selection.match([], base_dir) }
        .to raise_error(Excavate::TargetNotFoundError)
    end
  end

  describe ".from_filter + #match" do
    it "returns all paths whose relative name matches the glob" do
      paths = [abs("file1"), abs("file2"), abs("other.txt")]
      selection = described_class.from_filter("file*")

      expect(selection.match(paths, base_dir))
        .to contain_exactly(abs("file1"), abs("file2"))
    end

    it "supports ** globs across directory separators" do
      paths = [abs("a/x.txt"), abs("b/y.txt"), abs("ignore")]
      selection = described_class.from_filter("**/*.txt")

      expect(selection.match(paths, base_dir))
        .to contain_exactly(abs("a/x.txt"), abs("b/y.txt"))
    end

    it "raises TargetNotFoundError when the filter matches nothing" do
      paths = [abs("file1")]
      selection = described_class.from_filter("nomatch*")

      expect { selection.match(paths, base_dir) }
        .to raise_error(Excavate::TargetNotFoundError, /nomatch\*/)
    end
  end
end
