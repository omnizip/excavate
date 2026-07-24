require "excavate"

RSpec.shared_context "fresh work dir" do
  around do |example|
    dir = Dir.mktmpdir
    Dir.chdir(dir) do
      @temp_dir = dir

      example.run

      @temp_dir = nil
    end
  ensure
    Excavate::Filesystem.remove_recursive(dir) if dir && Dir.exist?(dir)
  end
end
