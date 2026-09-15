require "rails_helper"

RSpec.describe GameBreakdown::Timeline::Warning do
  let(:breakdown) { build_stubbed(:game_breakdown) }

  describe ".new" do
    context "when the code is unknown" do
      it "raises" do
        expect { described_class.new(code: :unknown, record: breakdown) }.to raise_error(ArgumentError, "unknown warning code: unknown")
      end
    end

    context "when only code and record are given" do
      subject(:warning) { described_class.new(code: :missing_don, record: breakdown) }

      it "has no rule" do
        expect(warning.rule).to be_nil
      end

      it "has no details" do
        expect(warning.details).to eq({})
      end
    end
  end

  describe ".for_seat" do
    subject(:warning) { described_class.for_seat(:repeated_nomination, breakdown, 4, rule: "4.4.2") }

    it "keeps the seat in the details" do
      expect(warning).to eq(described_class.new(code: :repeated_nomination, record: breakdown, rule: "4.4.2", details: { seat: 4 }))
    end

    context "when no rule is given" do
      subject(:warning) { described_class.for_seat(:eliminated_speaker, breakdown, 4) }

      it "has no rule" do
        expect(warning.rule).to be_nil
      end
    end
  end

  describe "#message" do
    context "when the warning has details" do
      subject(:warning) { described_class.for_seat(:eliminated_speaker, breakdown, 4) }

      it "interpolates them" do
        expect(warning.message).to eq("Речь выбывшего игрока 4")
      end
    end

    context "when the warning has no details" do
      subject(:warning) { described_class.new(code: :missing_don, record: breakdown) }

      it "translates the code" do
        expect(warning.message).to eq("Не указан дон")
      end
    end
  end

  describe "CODES" do
    described_class::CODES.each do |code|
      %i[ru en].each do |locale|
        it "translates #{code} in #{locale}" do
          expect(I18n.exists?("game_breakdowns.warnings.#{code}", locale)).to be(true)
        end
      end
    end
  end
end
