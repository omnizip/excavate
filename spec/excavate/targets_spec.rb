require "spec_helper"

RSpec.describe Excavate::Targets do
  include_context "fresh work dir"

  describe ".ensure_absent" do
    it "does not raise when nothing exists at the path" do
      expect { described_class.ensure_absent("nope") }.not_to raise_error
    end

    it "raises TargetExistsError naming an existing file" do
      FileUtils.touch("taken.txt")

      expect { described_class.ensure_absent("taken.txt") }
        .to raise_error(Excavate::TargetExistsError,
                        "Target file `taken.txt` already exists.")
    end

    it "raises TargetExistsError naming an existing directory" do
      FileUtils.mkdir("taken")

      expect { described_class.ensure_absent("taken") }
        .to raise_error(Excavate::TargetExistsError,
                        "Target directory `taken` already exists.")
    end
  end

  describe ".ensure_empty" do
    it "does not raise when the directory has no entries" do
      FileUtils.mkdir("empty_target")

      expect { described_class.ensure_empty("empty_target") }
        .not_to raise_error
    end

    it "raises TargetNotEmptyError when the directory has an entry" do
      FileUtils.mkdir("full_target")
      FileUtils.touch(File.join("full_target", "occupant.txt"))

      expect { described_class.ensure_empty("full_target") }
        .to raise_error(Excavate::TargetNotEmptyError,
                        "Target directory `full_target` is not empty.")
    end

    it "reports a regular file as a non-empty target" do
      FileUtils.touch("a_file")

      expect { described_class.ensure_empty("a_file") }
        .to raise_error(Excavate::TargetNotEmptyError,
                        "Target directory `a_file` is not empty.")
    end
  end

  describe ".create_default" do
    it "creates a directory named after the source basename" do
      target = described_class.create_default("/elsewhere/fonts.zip")

      expect(target).to eq(File.expand_path("fonts"))
      expect(File.directory?("fonts")).to be true
    end

    it "raises TargetExistsError when the default target exists" do
      FileUtils.mkdir("fonts")

      expect { described_class.create_default("/elsewhere/fonts.zip") }
        .to raise_error(Excavate::TargetExistsError,
                        "Target directory `fonts` already exists.")
    end
  end
end
