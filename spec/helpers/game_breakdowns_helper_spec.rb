require "rails_helper"

RSpec.describe GameBreakdownsHelper do
  describe "#breakdown_result_label" do
    it "translates a known result" do
      expect(helper.breakdown_result_label("city")).to eq(I18n.t("game_breakdowns.results.city"))
    end

    it "falls back to the unknown label for nil" do
      expect(helper.breakdown_result_label(nil)).to eq(I18n.t("game_breakdowns.results.unknown"))
    end

    it "falls back to the unknown label for a blank string" do
      expect(helper.breakdown_result_label("")).to eq(I18n.t("game_breakdowns.results.unknown"))
    end
  end

  describe "#breakdown_seat_names" do
    let(:breakdown) { create(:game_breakdown) }

    before { breakdown.seats.find_by(number: 2).update!(name: "Гость") }

    it "maps every seat number to its name" do
      expect(helper.breakdown_seat_names(breakdown)).to include(1 => nil, 2 => "Гость")
    end

    it "covers all ten seats" do
      expect(helper.breakdown_seat_names(breakdown).keys).to eq((1..10).to_a)
    end
  end

  describe "#breakdown_seat_label" do
    it "appends the name when present" do
      expect(helper.breakdown_seat_label({ 3 => "Гость" }, 3)).to eq("3 — Гость")
    end

    it "returns the bare number when the name is blank" do
      expect(helper.breakdown_seat_label({ 3 => "" }, 3)).to eq("3")
    end

    it "returns the bare number when the seat is unknown" do
      expect(helper.breakdown_seat_label({}, 3)).to eq("3")
    end
  end
end
