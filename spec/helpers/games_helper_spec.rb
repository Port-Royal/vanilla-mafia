require "rails_helper"

RSpec.describe GamesHelper do
  describe "#overlay_custom_style" do
    it "returns empty string when no config values set" do
      config = { font_size: nil, color: nil }

      expect(helper.overlay_custom_style(config)).to eq("")
    end

    it "returns font-size when set" do
      config = { font_size: 24, color: nil }

      expect(helper.overlay_custom_style(config)).to eq("font-size: 24px")
    end

    it "returns color when set" do
      config = { font_size: nil, color: "ff0000" }

      expect(helper.overlay_custom_style(config)).to eq("color: #ff0000")
    end

    it "returns both font-size and color when both set" do
      config = { font_size: 16, color: "00ff00" }

      expect(helper.overlay_custom_style(config)).to eq("font-size: 16px; color: #00ff00")
    end
  end

  describe "#overlay_player_status" do
    it "returns nil when no participation is given" do
      expect(helper.overlay_player_status(nil)).to be_nil
    end

    it "returns the participation status as a symbol" do
      participation = instance_double(GameParticipation, status: "killed_by_mafia")

      expect(helper.overlay_player_status(participation)).to eq(:killed_by_mafia)
    end

    it "returns :alive for a freshly built participation" do
      participation = GameParticipation.new

      expect(helper.overlay_player_status(participation)).to eq(:alive)
    end

    it "reflects a voted_out participation" do
      participation = GameParticipation.new(status: :voted_out)

      expect(helper.overlay_player_status(participation)).to eq(:voted_out)
    end

    it "reflects a banned participation" do
      participation = GameParticipation.new(status: :banned)

      expect(helper.overlay_player_status(participation)).to eq(:banned)
    end
  end

  describe "#overlay_status_class" do
    it "returns a non-empty class string for alive" do
      expect(helper.overlay_status_class(:alive)).to include("green")
    end

    it "returns a non-empty class string for killed_by_mafia" do
      expect(helper.overlay_status_class(:killed_by_mafia)).to include("red")
    end

    it "returns a non-empty class string for voted_out" do
      expect(helper.overlay_status_class(:voted_out)).to include("orange")
    end

    it "returns a non-empty class string for banned" do
      expect(helper.overlay_status_class(:banned)).to include("gray")
    end

    it "returns an empty string for unknown status" do
      expect(helper.overlay_status_class(:unknown)).to eq("")
    end
  end

  describe "#overlay_table_label" do
    let(:game) { Game.new(table_number: table_number) }

    context "when the table number is set" do
      let(:table_number) { 3 }

      it "labels the table" do
        expect(helper.overlay_table_label(game)).to eq("Стол 3")
      end
    end

    context "when the table number is blank" do
      let(:table_number) { nil }

      it "returns nil" do
        expect(helper.overlay_table_label(game)).to be_nil
      end
    end
  end

  describe "#overlay_game_label" do
    let(:game) { Game.new(game_number: 5) }

    it "labels the game by its number" do
      expect(helper.overlay_game_label(game)).to eq("Игра 5")
    end
  end

  describe "#overlay_judge_label" do
    let(:game) { Game.new(judge: judge) }

    context "when the judge is set" do
      let(:judge) { "Кузнецов" }

      it "labels the judge" do
        expect(helper.overlay_judge_label(game)).to eq("Судья Кузнецов")
      end
    end

    context "when the judge is blank" do
      let(:judge) { " " }

      it "returns nil" do
        expect(helper.overlay_judge_label(game)).to be_nil
      end
    end
  end
end
