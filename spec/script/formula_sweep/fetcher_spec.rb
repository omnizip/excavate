# frozen_string_literal: true

require "spec_helper"
require "digest"
require "tmpdir"
require_relative "../../../script/formula_sweep/fetcher"

# Shared cache and HTTP fixtures keep each failure scenario explicit.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe FormulaSweep::Fetcher, :aggregate_failures do
  subject(:fetcher) { described_class.new(cache_dir: cache_dir) }

  let(:directory) { Dir.mktmpdir("formula-fetcher") }
  let(:cache_dir) { File.join(directory, "cache") }
  let(:contents) { "archive bytes\x00\xff".b }
  let(:checksum) { Digest::SHA256.hexdigest(contents) }
  let(:source) { File.join(directory, "archive.zip") }
  let(:file_url) do
    "file:///#{URI::DEFAULT_PARSER.escape(source.delete_prefix('/'))}"
  end
  let(:url) { file_url }
  let(:resource) do
    { "urls" => [url], "sha256" => checksum, "file_size" => contents.bytesize }
  end

  before { File.binwrite(source, contents) }
  after { FileUtils.remove_entry(directory) }

  it "downloads an archive into the checksum cache" do
    result = fetcher.fetch(resource)

    expect(result.path).to eq(File.join(cache_dir, checksum))
    expect(File.binread(result.path)).to eq(contents)
    expect(result.errors).to be_empty
    expect(result.skipped).to be(false)
  end

  it "closes the temporary download before renaming it on Windows" do
    temporary = Tempfile.new("archive", directory)
    allow(Tempfile).to receive(:create).and_yield(temporary)
    allow(File).to receive(:rename).and_wrap_original do |rename, *args|
      raise Errno::EACCES unless temporary.closed?

      rename.call(*args)
    end

    result = fetcher.fetch(resource)

    expect(result.errors).to be_empty
    expect(File.binread(result.path)).to eq(contents)
  ensure
    temporary.close!
  end

  it "opens Windows drive paths from escaped local file URLs" do
    resource["urls"] = ["file:///C:/archive%20files/archive.zip"]
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with("C:/archive files/archive.zip", "rb")
      .and_wrap_original do |_open, *_args, &block|
        File.open(source, "rb", &block)
      end

    result = fetcher.fetch(resource)

    expect(result.errors).to be_empty
    expect(File.binread(result.path)).to eq(contents)
  end

  it "tries URLs in order and stops after the first success" do
    missing = "#{file_url}.missing"
    resource["urls"] = [missing, url, "unsupported://never-tried"]

    result = fetcher.fetch(resource)

    expect(File.binread(result.path)).to eq(contents)
    expect(result.errors.keys).to eq([missing])
    expect(result.errors[missing]).to match(/missing/)
  end

  it "returns an error for every failed URL" do
    resource["urls"] = ["#{file_url}.missing", "unsupported://archive"]

    result = fetcher.fetch(resource)

    expect(result.path).to be_nil
    expect(result.errors.keys).to eq(resource["urls"])
    expect(result.errors.values).to all(be_a(String).and(satisfy { |s|
      !s.empty?
    }))
    expect(Dir.children(cache_dir)).to be_empty
  end

  it "rejects mismatched bytes without leaving a cache or temporary file" do
    File.binwrite(source, "bad bytes")

    result = fetcher.fetch(resource)

    expect(result.path).to be_nil
    expect(result.errors.fetch(url)).to match(/SHA256 mismatch/)
    expect(Dir.children(cache_dir)).to be_empty
  end

  it "falls back after a checksum failure" do
    bad_source = File.join(directory, "bad.zip")
    File.write(bad_source, "bad bytes")
    bad_url = file_url.sub("archive.zip", "bad.zip")
    resource["urls"].unshift(bad_url)

    result = fetcher.fetch(resource)

    expect(File.binread(result.path)).to eq(contents)
    expect(result.errors.keys).to eq([bad_url])
    expect(Dir.children(cache_dir)).to eq([checksum])
  end

  it "reuses verified cache bytes without accessing URLs" do
    cached = fetcher.fetch(resource).path
    File.unlink(source)

    result = fetcher.fetch(resource)

    expect(result.path).to eq(cached)
    expect(result.errors).to be_empty
    expect(File.binread(result.path)).to eq(contents)
  end

  it "replaces corrupt cached bytes from the source" do
    cached = fetcher.fetch(resource).path
    File.write(cached, "corrupt")

    result = fetcher.fetch(resource)

    expect(File.binread(result.path)).to eq(contents)
    expect(result.errors).to be_empty
  end

  it "does not return corrupt cache bytes if refetch fails" do
    cached = fetcher.fetch(resource).path
    File.write(cached, "corrupt")
    File.unlink(source)

    result = fetcher.fetch(resource)

    expect(result.path).to be_nil
    expect(result.errors.keys).to eq([url])
    expect(File.exist?(cached)).to be(false)
  end

  it "accepts symbol keys" do
    result = fetcher.fetch(urls: [url], sha256: checksum,
                           file_size: contents.bytesize)

    expect(File.binread(result.path)).to eq(contents)
  end

  context "with multiple accepted checksums" do
    let(:other_checksum) { Digest::SHA256.hexdigest("other archive") }

    before { resource["sha256"] = [other_checksum, checksum] }

    it "accepts any listed checksum and caches under the first" do
      result = fetcher.fetch(resource)

      expect(result.path).to eq(File.join(cache_dir, other_checksum))
      expect(File.binread(result.path)).to eq(contents)
      expect(result.errors).to be_empty
    end

    it "reuses a cache matching a later checksum without downloading" do
      cached = fetcher.fetch(resource).path
      File.unlink(source)

      result = fetcher.fetch(resource)

      expect(result.path).to eq(cached)
      expect(File.binread(result.path)).to eq(contents)
      expect(result.errors).to be_empty
    end

    it "rejects bytes matching none of the checksums" do
      File.binwrite(source, "unaccepted archive")

      result = fetcher.fetch(resource)

      expect(result.path).to be_nil
      expect(result.errors.fetch(url)).to include("SHA256 mismatch")
      expect(Dir.children(cache_dir)).to be_empty
    end
  end

  context "without usable checksums" do
    it "returns a resource error when sha256 is missing" do
      resource.delete("sha256")

      result = fetcher.fetch(resource)

      expect(result.path).to be_nil
      expect(result.errors.fetch(:sha256)).to include("sha256")
      expect(result.skipped).to be(false)
      expect(File.exist?(cache_dir)).to be(false)
    end

    it "returns a resource error for an empty checksum list" do
      resource["sha256"] = []

      result = fetcher.fetch(resource)

      expect(result.path).to be_nil
      expect(result.errors.fetch(:sha256)).to include("sha256")
    end

    it "returns a resource error for a malformed checksum list" do
      resource["sha256"] = [checksum, "../invalid"]

      result = fetcher.fetch(resource)

      expect(result.path).to be_nil
      expect(result.errors.fetch(:sha256)).to include("sha256")
      expect(File.exist?(cache_dir)).to be(false)
    end
  end

  it "skips Google sources without creating a cache" do
    resource["source"] = "google"

    result = fetcher.fetch(resource)

    expect(result.skipped).to be(true)
    expect(result.path).to be_nil
    expect(result.errors).to be_empty
    expect(File.exist?(cache_dir)).to be(false)
  end

  context "with HTTP archives" do
    let(:url) { "https://archives.example/archive" }
    let(:http) { instance_double(Net::HTTP) }
    let(:redirect) { Net::HTTPFound.new("1.1", "302", "Found") }
    let(:success) { Net::HTTPOK.new("1.1", "200", "OK") }
    let(:responses) { [redirect, success] }
    let(:requests) { [] }

    before do
      redirect["location"] = "/final"
      allow(success).to receive(:read_body)
        .and_yield(contents[0, 5]).and_yield(contents[5..])
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |request, &block|
        requests << request
        block.call(responses.shift)
      end
    end

    it "follows relative HTTPS redirects and streams the archive" do
      result = fetcher.fetch(resource)

      expect(File.binread(result.path)).to eq(contents)
      expect(requests.map(&:path)).to eq(%w[/archive /final])
      expect(Net::HTTP).to have_received(:start).with(
        "archives.example", 443,
        use_ssl: true, open_timeout: 30, read_timeout: 60
      ).twice
    end

    context "when redirects loop" do
      let(:responses) { Array.new(6, redirect) }

      it "returns an error after a bounded number of redirects" do
        result = fetcher.fetch(resource)

        expect(result.path).to be_nil
        expect(result.errors.fetch(url)).to match(/redirect/i)
        expect(requests.size).to eq(6)
        expect(Dir.children(cache_dir)).to be_empty
      end
    end

    context "when the server returns an error" do
      let(:responses) { [Net::HTTPNotFound.new("1.1", "404", "Not Found")] }

      it "records the HTTP error and cleans up rejected downloads" do
        result = fetcher.fetch(resource)

        expect(result.path).to be_nil
        expect(result.errors.fetch(url)).to include("HTTP 404 Not Found")
        expect(Dir.children(cache_dir)).to be_empty
      end

      it "tries the next URL after an HTTP error" do
        resource["urls"] << file_url

        result = fetcher.fetch(resource)

        expect(File.binread(result.path)).to eq(contents)
        expect(result.errors.keys).to eq([url])
        expect(result.errors.fetch(url)).to include("HTTP 404 Not Found")
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
