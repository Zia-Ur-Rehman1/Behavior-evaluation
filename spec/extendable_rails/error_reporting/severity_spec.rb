# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExtendableRails::ErrorReporting::Severity do
  describe "LEVELS" do
    it "defines ordered severity levels" do
      expect(described_class::LEVELS).to eq(%i[normal warning high critical])
    end

    it "is frozen" do
      expect(described_class::LEVELS).to be_frozen
    end
  end

  describe ".coerce" do
    it "accepts a valid symbol" do
      expect(described_class.coerce(:warning)).to eq(:warning)
    end

    it "accepts a valid string" do
      expect(described_class.coerce("critical")).to eq(:critical)
    end

    it "raises ArgumentError for an unknown level" do
      expect { described_class.coerce(:bogus) }
        .to raise_error(ArgumentError, /Unknown severity/)
    end

    it "includes valid levels in the error message" do
      expect { described_class.coerce(:nope) }
        .to raise_error(ArgumentError, /normal, warning, high, critical/)
    end
  end

  describe ".rank" do
    it "returns 0 for normal" do
      expect(described_class.rank(:normal)).to eq(0)
    end

    it "returns 3 for critical" do
      expect(described_class.rank(:critical)).to eq(3)
    end

    it "is monotonic" do
      ranks = described_class::LEVELS.map { |l| described_class.rank(l) }
      expect(ranks).to eq(ranks.sort)
    end
  end

  describe ".meets?" do
    it "is true when level equals threshold" do
      expect(described_class.meets?(:warning, threshold: :warning)).to be true
    end

    it "is true when level exceeds threshold" do
      expect(described_class.meets?(:critical, threshold: :warning)).to be true
    end

    it "is false when level is below threshold" do
      expect(described_class.meets?(:normal, threshold: :high)).to be false
    end

    it "coerces string arguments" do
      expect(described_class.meets?("high", threshold: "normal")).to be true
    end
  end

  describe ".label" do
    it "returns a human-readable label" do
      expect(described_class.label(:critical)).to eq("Critical")
    end

    it "works for every level" do
      described_class::LEVELS.each do |level|
        expect(described_class.label(level)).to be_a(String)
      end
    end
  end

  describe ".description" do
    it "returns a descriptive message" do
      expect(described_class.description(:warning))
        .to eq("Unexpected condition – system recovered automatically")
    end

    it "describes critical appropriately" do
      expect(described_class.description(:critical)).to match(/immediate attention/i)
    end

    it "provides a description for every level" do
      described_class::LEVELS.each do |level|
        expect(described_class.description(level)).not_to be_empty
      end
    end
  end
end
