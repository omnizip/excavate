# frozen_string_literal: true

require "digest"
require "fileutils"
require "net/http"
require "tempfile"
require "uri"

module FormulaSweep
  class Fetcher
    Result = Struct.new(:path, :errors, :skipped, keyword_init: true)
    REDIRECT_LIMIT = 5

    def initialize(cache_dir:)
      @cache_dir = File.expand_path(cache_dir)
    end

    def fetch(resource)
      if value(resource, :source) == "google"
        return Result.new(errors: {}, skipped: true)
      end

      checksum = checksum_for(resource)
      FileUtils.mkdir_p(@cache_dir)
      path = File.join(@cache_dir, checksum)
      if File.file?(path) && Digest::SHA256.file(path).hexdigest == checksum
        return Result.new(path: path, errors: {}, skipped: false)
      end

      FileUtils.rm_f(path)
      fetch_urls(Array(value(resource, :urls)), path, checksum)
    end

    private

    def checksum_for(resource)
      checksum = value(resource, :sha256).to_s.downcase
      unless checksum.match?(/\A[0-9a-f]{64}\z/)
        raise ArgumentError, "sha256 must contain 64 hexadecimal characters"
      end

      checksum
    end

    def fetch_urls(urls, path, checksum)
      errors = {}
      urls.each do |url|
        download(url, path, checksum)
        return Result.new(path: path, errors: errors, skipped: false)
      rescue StandardError => e
        errors[url] = "#{e.class}: #{e.message}"
      end
      Result.new(errors: errors, skipped: false)
    end

    def value(resource, key)
      resource[key.to_s] || resource[key]
    end

    def download(url, path, checksum)
      Tempfile.create(["archive-", ".part"], @cache_dir) do |file|
        file.binmode
        transfer(URI.parse(url), file, REDIRECT_LIMIT)
        file.flush
        actual = Digest::SHA256.file(file.path).hexdigest
        unless actual == checksum
          raise IOError, "SHA256 mismatch: expected #{checksum}, got #{actual}"
        end

        File.rename(file.path, path)
      end
    end

    def transfer(uri, file, redirects)
      case uri.scheme
      when "file"
        transfer_file(uri, file)
      when "http", "https"
        transfer_http(uri, file, redirects)
      else
        raise ArgumentError, "unsupported URL scheme: #{uri.scheme}"
      end
    end

    def transfer_file(uri, file)
      unless uri.host.nil? || ["", "localhost"].include?(uri.host)
        raise ArgumentError, "file URL must refer to the local host"
      end

      File.open(URI::DEFAULT_PARSER.unescape(uri.path), "rb") do |source|
        IO.copy_stream(source, file)
      end
    end

    def transfer_http(uri, file, redirects)
      options = { use_ssl: uri.scheme == "https",
                  open_timeout: 30, read_timeout: 60 }
      Net::HTTP.start(uri.host, uri.port, **options) do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          handle_response(response, uri, file, redirects)
        end
      end
    end

    def handle_response(response, uri, file, redirects)
      case response
      when Net::HTTPSuccess
        response.read_body { |chunk| file.write(chunk) }
      when Net::HTTPRedirection
        follow_redirect(response, uri, file, redirects)
      else
        raise IOError, "HTTP #{response.code} #{response.message}"
      end
    end

    def follow_redirect(response, uri, file, redirects)
      raise IOError, "too many redirects" if redirects.zero?
      raise IOError, "redirect without Location" unless response["location"]

      target = URI.join(uri.to_s, response["location"])
      unless %w[http https].include?(target.scheme)
        raise IOError, "unsupported redirect scheme: #{target.scheme}"
      end

      transfer_http(target, file, redirects - 1)
    end
  end
end
