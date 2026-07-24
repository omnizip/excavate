# frozen_string_literal: true

module Excavate
  class FileMagic
    # A magic-byte signature: where in the file to look, what bytes to
    # expect, and which type they identify.
    Signature = Struct.new(:offset, :magic, :type)

    SIGNATURES = [
      Signature.new(0,   "MSCF\x00\x00\x00\x00".b, :cab),
      Signature.new(0,   "\xFD7zXZ\x00".b,         :xz),
      Signature.new(0,   "\x1F\x8B".b,             :gzip),
      Signature.new(257, "ustar".b,                :tar),
      Signature.new(0,   "7z\xBC\xAF\x27\x1C".b,   :seven_zip),
      Signature.new(0,   "PK\x03\x04".b,           :zip),
      Signature.new(0,   "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".b, :ole),
      Signature.new(0,   "xar!".b,                 :xar),
      Signature.new(0,   "\xED\xAB\xEE\xDB".b,     :rpm),
      Signature.new(0,   "070707".b,               :cpio),
      Signature.new(0,   "070701".b,               :cpio),
      Signature.new(0,   "070702".b,               :cpio),
      Signature.new(0,   "MZ".b,                   :exe),
    ].freeze

    MAX_READ = SIGNATURES.map do |signature|
      signature.offset + signature.magic.bytesize
    end.max

    def self.detect(path)
      detect_bytes(File.read(path, MAX_READ, mode: "rb"))
    end

    def self.detect_bytes(data)
      return nil if data.nil? || data.empty?

      matching_signature(data)&.type
    end

    def self.matching_signature(data)
      SIGNATURES.find do |signature|
        next if data.bytesize < signature.offset + signature.magic.bytesize

        slice = data.byteslice(signature.offset, signature.magic.bytesize)
        slice == signature.magic
      end
    end
    private_class_method :matching_signature
  end
end
