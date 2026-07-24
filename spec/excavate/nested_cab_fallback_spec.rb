require "spec_helper"

RSpec.describe Excavate::NestedCabFallback do
  def error_with(message)
    StandardError.new(message)
  end

  describe ".applies_to?" do
    it "is true for an :exe whose error starts with 'Invalid file format'" do
      expect(described_class.applies_to?(:exe,
                                         error_with("Invalid file format")))
        .to be true
    end

    it "is true for an :exe whose error is 'Unrecognized archive format'" do
      expect(described_class.applies_to?(:exe,
                                         error_with("Unrecognized" \
                                                    " archive format")))
        .to be true
    end

    it "is true for an :exe whose error mentions 'Invalid .7z signature'" do
      expect(described_class.applies_to?(:exe,
                                         error_with("Invalid" \
                                                    " .7z signature")))
        .to be true
    end

    it "is false for an :exe with an unrelated message" do
      expect(described_class.applies_to?(:exe, error_with("disk full")))
        .to be false
    end

    it "is false for a non-exe type even with a matching message" do
      expect(described_class.applies_to?(:cab,
                                         error_with("Invalid file format")))
        .to be false
      expect(described_class.applies_to?(:seven_zip,
                                         error_with("Invalid .7z signature")))
        .to be false
    end

    it "is false for nil type" do
      expect(described_class.applies_to?(nil,
                                         error_with("Invalid file format")))
        .to be false
    end
  end
end
