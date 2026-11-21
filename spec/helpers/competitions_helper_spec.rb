require "rails_helper"

RSpec.describe CompetitionsHelper do
  describe "#win_percentage" do
    let(:player) { Data.define(:wins_count, :games_count).new(wins_count: wins, games_count: games) }

    context "when player has no games" do
      let(:wins) { 0 }
      let(:games) { 0 }

      it "returns 0.0" do
        expect(helper.win_percentage(player)).to eq(0.0)
      end
    end

    context "when player has won all games" do
      let(:wins) { 3 }
      let(:games) { 3 }

      it "returns 100.0" do
        expect(helper.win_percentage(player)).to eq(100.0)
      end
    end

    context "when player has partial wins" do
      let(:wins) { 1 }
      let(:games) { 3 }

      it "returns the rounded percentage" do
        expect(helper.win_percentage(player)).to eq(33.3)
      end
    end
  end

  describe "#children_label" do
    context "when the competition is a season" do
      let(:competition) { build(:competition, :season) }

      it { expect(helper.children_label(competition)).to eq("Серии") }

      {
        1 => "1 серия", 2 => "2 серии", 5 => "5 серий", 11 => "11 серий", 21 => "21 серия"
      }.each do |count, phrase|
        context "with a count of #{count}" do
          it { expect(helper.children_label(competition, count:)).to eq(phrase) }
        end
      end

      context "with the English locale" do
        around { |example| I18n.with_locale(:en) { example.run } }

        it { expect(helper.children_label(competition)).to eq("Series") }
        it { expect(helper.children_label(competition, count: 1)).to eq("1 series") }
        it { expect(helper.children_label(competition, count: 4)).to eq("4 series") }
      end
    end

    context "when the competition is a tournament" do
      let(:competition) { build(:competition, :tournament) }

      it { expect(helper.children_label(competition)).to eq("Этапы") }

      {
        1 => "1 этап", 2 => "2 этапа", 5 => "5 этапов", 11 => "11 этапов", 21 => "21 этап"
      }.each do |count, phrase|
        context "with a count of #{count}" do
          it { expect(helper.children_label(competition, count:)).to eq(phrase) }
        end
      end

      context "with the English locale" do
        around { |example| I18n.with_locale(:en) { example.run } }

        it { expect(helper.children_label(competition)).to eq("Stages") }
        it { expect(helper.children_label(competition, count: 1)).to eq("1 stage") }
        it { expect(helper.children_label(competition, count: 3)).to eq("3 stages") }
      end
    end

    context "when the competition is a minicup with children" do
      let(:competition) { build(:competition, :minicup) }

      it { expect(helper.children_label(competition)).to eq("Этапы") }
    end
  end

  describe "#competition_dates" do
    let(:competition) { build(:competition, started_on:, ended_on:) }
    let(:started_on) { Date.new(2026, 9, 1) }
    let(:ended_on) { nil }

    context "when the competition is running" do
      it { expect(helper.competition_dates(competition)).to eq("с 01.09.2026") }

      context "without a start date" do
        let(:started_on) { nil }

        it { expect(helper.competition_dates(competition)).to eq("") }
      end

      context "with the English locale" do
        around { |example| I18n.with_locale(:en) { example.run } }

        it { expect(helper.competition_dates(competition)).to eq("since 01.09.2026") }
      end
    end

    context "when the competition is finished" do
      let(:ended_on) { Date.new(2026, 9, 30) }

      it { expect(helper.competition_dates(competition)).to eq("01.09.2026 – 30.09.2026") }

      context "without a start date" do
        let(:started_on) { nil }

        it { expect(helper.competition_dates(competition)).to eq("30.09.2026") }
      end
    end
  end
end
