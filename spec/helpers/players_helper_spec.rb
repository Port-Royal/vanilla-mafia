require "rails_helper"

RSpec.describe PlayersHelper do
  describe "#player_initial" do
    it "returns the first letter of a Cyrillic name" do
      expect(helper.player_initial("финчер")).to eq("Ф")
    end

    it "returns the first letter of a Latin name" do
      expect(helper.player_initial("baron")).to eq("B")
    end

    it "ignores leading spaces" do
      expect(helper.player_initial("  ласка ")).to eq("Л")
    end

    it "ignores leading spaces without trailing ones" do
      expect(helper.player_initial("  ласка")).to eq("Л")
    end

    it "returns an empty string for a blank name" do
      expect(helper.player_initial(" ")).to eq("")
    end
  end

  describe "#profile_number_label" do
    around { |example| I18n.with_locale(:ru) { example.run } }

    {
      1 => "игра", 2 => "игры", 5 => "игр", 11 => "игр", 21 => "игра", 22 => "игры"
    }.each do |count, word|
      it "says «#{word}» for #{count} games" do
        expect(helper.profile_number_label(:games, count)).to eq(word)
      end
    end

    {
      1 => "турнир", 3 => "турнира", 5 => "турниров", 11 => "турниров", 21 => "турнир"
    }.each do |count, word|
      it "says «#{word}» for #{count} competitions" do
        expect(helper.profile_number_label(:competitions, count)).to eq(word)
      end
    end

    {
      1 => "награда", 2 => "награды", 11 => "наград", 21 => "награда"
    }.each do |count, word|
      it "says «#{word}» for #{count} awards" do
        expect(helper.profile_number_label(:awards, count)).to eq(word)
      end
    end
  end

  describe "#profile_result_pill" do
    around { |example| I18n.with_locale(:ru) { example.run } }

    let(:game) { build(:game, result:, hide_roles:) }
    let(:hide_roles) { false }
    let(:participation) { build(:game_participation, game:, role: build(:role, code: "peace")) }
    let(:pill) { Nokogiri::HTML.fragment(helper.profile_result_pill(participation).to_s).at_css("span") }

    context "when the player's side won" do
      let(:result) { "peace_victory" }

      it("is a gold pill saying «Победа»") { expect([ pill["class"], pill.text ]).to eq([ "vm-pill vm-pill--gold", "Победа" ]) }
    end

    context "when the player's side lost" do
      let(:result) { "mafia_victory" }

      it("is a plain pill saying «Поражение»") { expect([ pill["class"], pill.text ]).to eq([ "vm-pill", "Поражение" ]) }
    end

    context "when the game was a draw" do
      let(:result) { "draw" }

      it("is a neutral pill saying «Ничья»") { expect([ pill["class"], pill.text ]).to eq([ "vm-pill vm-pill--neutral", "Ничья" ]) }
    end

    context "when the game is in progress" do
      let(:result) { "in_progress" }

      it("is nil") { expect(helper.profile_result_pill(participation)).to be_nil }
    end

    context "when the game is in progress with hidden roles" do
      let(:result) { "in_progress" }
      let(:hide_roles) { true }

      it("is nil") { expect(helper.profile_result_pill(participation)).to be_nil }
    end
  end

  describe "#profile_game_label" do
    around { |example| I18n.with_locale(:ru) { example.run } }

    let(:root) { build(:competition, :season, name: "Сезон 4") }
    let(:series) { build(:competition, :series, name: "Серия 2", parent: root) }
    let(:stored_root) { build_stubbed(:competition, :season, name: "Сезон 4") }
    let(:root_copy) { Competition.new(id: stored_root.id, name: "Сезон 4") }

    it "names the series when the game belongs to one" do
      expect(helper.profile_game_label(build(:game, competition: series, game_number: 2), root)).to eq("Серия 2 · Игра 2")
    end

    it "gives just the number when the game belongs to the root itself" do
      expect(helper.profile_game_label(build(:game, competition: root, game_number: 7), root)).to eq("Игра 7")
    end

    it "treats another copy of the root record as the root" do
      expect(helper.profile_game_label(build(:game, competition: stored_root, game_number: 7), root_copy))
        .to eq("Игра 7")
    end
  end

  describe "#profile_won?" do
    let(:participation) { build(:game_participation, game: build(:game, result:), role: build(:role, code: "mafia")) }

    context "when the player's side won" do
      let(:result) { "mafia_victory" }

      it { expect(helper.profile_won?(participation)).to be(true) }
    end

    context "when the player's side lost" do
      let(:result) { "peace_victory" }

      it { expect(helper.profile_won?(participation)).to be(false) }
    end

    context "when the game is in progress" do
      let(:result) { "in_progress" }

      it { expect(helper.profile_won?(participation)).to be(false) }
    end
  end
end
