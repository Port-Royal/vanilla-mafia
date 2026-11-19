require "rails_helper"

RSpec.describe ResultsHelper, type: :helper do
  describe "RESULT_PILL_MODIFIERS" do
    it { expect(ResultsHelper::RESULT_PILL_MODIFIERS).to be_frozen }
  end

  describe "#game_result_pill" do
    let(:game) { build_stubbed(:game, result: result) }
    let(:pill) { Nokogiri::HTML.fragment(helper.game_result_pill(game)).at_css("span") }
    let(:label) { I18n.t("activerecord.attributes.game.results.#{result}") }

    shared_examples "a result pill" do |modifier|
      it { expect(pill["class"].split).to contain_exactly("vm-pill", modifier) }
      it { expect(pill.text).to eq(label) }
    end

    context "when civilians won" do
      let(:result) { "peace_victory" }

      it_behaves_like "a result pill", "vm-pill--gold"
    end

    context "when the mafia won" do
      let(:result) { "mafia_victory" }

      it_behaves_like "a result pill", "vm-pill--alert"
    end

    context "when the game is a draw" do
      let(:result) { "draw" }

      it_behaves_like "a result pill", "vm-pill--neutral"
    end

    context "when the game is in progress" do
      let(:result) { "in_progress" }

      it_behaves_like "a result pill", "vm-pill--neutral"
    end
  end
end
