# 04 — FileMagic::Signature value object

Status: **pending**

## Why

`FileMagic::SIGNATURES` is an array of `[offset, magic, type]` tuples.
Reading call sites like `SIGNATURES.map { |o, m, _| o + m.bytesize }` or
`SIGNATURES.each do |offset, magic, type|` requires the reader to memorise
the positional convention. A named value object removes that cognitive load
and documents intent.

## Plan

Introduce `FileMagic::Signature = Struct.new(:offset, :magic, :type)` and
rewrite SIGNATURES as a list of `Signature.new(...)` literals. Update
`detect_bytes` and `MAX_READ` to use field names.

Sketch:

```ruby
module Excavate
  class FileMagic
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

    MAX_READ = SIGNATURES.map { |s| s.offset + s.magic.bytesize }.max

    def self.detect(path)
      detect_bytes(File.read(path, MAX_READ, mode: "rb"))
    end

    def self.detect_bytes(data)
      return nil if data.nil? || data.empty?

      SIGNATURES.each do |signature|
        next if data.bytesize < signature.offset + signature.magic.bytesize

        return signature.type if data.byteslice(signature.offset, signature.magic.bytesize) == signature.magic
      end

      nil
    end
  end
end
```

`Signature` is internal to FileMagic so no autoload entry needed.

## Acceptance

- All file_magic_spec examples pass unchanged.
- No positional-destructuring of signature tuples remains.
