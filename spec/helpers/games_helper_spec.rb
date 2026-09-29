require "rails_helper"

RSpec.describe GamesHelper do
  describe "#overlay_custom_style" do
    it "returns empty string when the config has no style keys" do
      expect(helper.overlay_custom_style({})).to eq("")
    end

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

  describe "#overlay_role_badge" do
    {
      "sheriff" => "Ш",
      "don" => "Д",
      "mafia" => "М"
    }.each do |role_code, letter|
      context "when the role is #{role_code}" do
        it "returns the #{letter} letter" do
          expect(helper.overlay_role_badge(role_code)).to eq(letter)
        end
      end
    end

    [ "peace", nil, "unknown" ].each do |role_code|
      context "when the role is #{role_code.inspect}" do
        it "returns nil" do
          expect(helper.overlay_role_badge(role_code)).to be_nil
        end
      end
    end
  end

  describe "#overlay_eliminated?" do
    %i[killed_by_mafia voted_out banned].each do |status|
      context "when the status is #{status}" do
        it "is true" do
          expect(helper.overlay_eliminated?(status)).to be(true)
        end
      end
    end

    [ :alive, nil ].each do |status|
      context "when the status is #{status.inspect}" do
        it "is false" do
          expect(helper.overlay_eliminated?(status)).to be(false)
        end
      end
    end
  end

  describe "#overlay_status_icon" do
    let(:icon) { Nokogiri::HTML5.fragment(helper.overlay_status_icon(status)).at_css("svg") }

    %i[killed_by_mafia voted_out banned].each do |status_key|
      context "when the status is #{status_key}" do
        let(:status) { status_key }
        let(:source) { Nokogiri::XML(Rails.root.join("app/assets/images/overlay/status/#{status_key}.svg").read).root }

        it "inlines the #{status_key} icon file" do
          expect(icon.at_css("path")["d"]).to eq(source.at_xpath("//*[local-name()='path']")["d"])
        end

        it "returns markup safe to inline" do
          expect(helper.overlay_status_icon(status)).to be_html_safe
        end

        it "marks the icon with its status, sizing and accessibility attributes" do
          expect(icon.to_h).to include(
            "data-status" => status_key.to_s,
            "class" => "h-full w-full drop-shadow",
            "aria-hidden" => "true"
          )
        end
      end
    end

    [ :alive, nil ].each do |status_key|
      context "when the status is #{status_key.inspect}" do
        let(:status) { status_key }

        it "renders nothing" do
          expect(helper.overlay_status_icon(status)).to be_nil
        end
      end
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
    let(:game) { Game.new(game_number: 5, games_total: games_total) }

    context "when the total is set" do
      let(:games_total) { 8 }

      it "labels the game as a fraction of the total" do
        expect(helper.overlay_game_label(game)).to eq("Игра 5/8")
      end
    end

    context "when the total is blank" do
      let(:games_total) { nil }

      it "labels the game by its number" do
        expect(helper.overlay_game_label(game)).to eq("Игра 5")
      end
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
