# frozen_string_literal: true

module Excavate
  class FileMagic
    # [offset, magic_bytes, type]
    SIGNATURES = [
      [0, "MSCF\x00\x00\x00\x00".b, :cab],
      [0, "\xFD7zXZ\x00".b, :xz],
      [0, "\x1F\x8B".b, :gzip],
      [257, "ustar".b, :tar],
    ].freeze

    MAX_READ = SIGNATURES.map { |o, m, _| o + m.bytesize }.max

    def self.detect(path)
      beginning = File.read(path, MAX_READ, mode: "rb")
      detect_bytes(beginning)
    end

    def self.detect_bytes(data)
      return nil if data.nil? || data.empty?

      SIGNATURES.each do |offset, magic, type|
        next if data.bytesize < offset + magic.bytesize

        return type if data.byteslice(offset, magic.bytesize) == magic
      end

      nil
    end
  end
end
