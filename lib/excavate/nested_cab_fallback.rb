# frozen_string_literal: true

module Excavate
  # Decides whether a failed extraction of a `:exe`-typed archive
  # should be retried as a CAB.
  #
  # Some self-extracting EXEs produced by older Microsoft toolchains
  # wrap a CAB rather than a 7z payload. When the 7z reader fails to
  # parse one of these, it surfaces a small number of distinctive
  # error strings. Rather than sniffing those strings inline inside
  # Archive's rescue clause, the heuristic is named and tested here.
  class NestedCabFallback
    SIGNATURE_PHRASES = [
      /\AInvalid file format/,
      /\AUnrecognized archive format/,
      /Invalid \.7z signature/,
    ].freeze

    class << self
      def applies_to?(type, error)
        type == :exe && phrase_match?(error.message)
      end

      private

      def phrase_match?(message)
        SIGNATURE_PHRASES.any? { |pattern| pattern.match?(message) }
      end
    end
  end
end
