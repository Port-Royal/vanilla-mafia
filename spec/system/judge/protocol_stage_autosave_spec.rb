require "rails_helper"

RSpec.describe "Protocol stage autosave" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:competition) { create(:competition, :tournament, name: "Кубок Осени") }
  let_it_be(:stage) { create(:competition, :round, parent: competition, name: "Финал") }
  let_it_be(:other_competition) { create(:competition, :tournament, name: "Кубок Зимы") }
  let_it_be(:game) { create(:game, competition: competition) }

  # Waits until autosave has moved the game to the expected competition, then returns what is stored.
  def stored_competition(expected)
    page.document.synchronize do
      stored = game.reload.competition
      raise Capybara::ExpectationNotMet, "#{expected.name} not saved yet: #{stored.name}" unless stored == expected

      stored
    end
  end

  before do
    sign_in admin
    visit edit_judge_protocol_path(game)
    click_button I18n.t("game_protocols.autosave.toggle_off")
    select "Финал", from: "game_stage_id"
  end

  context "when a stage is picked" do
    it "moves the game to the stage" do
      expect(stored_competition(stage)).to eq(stage)
    end
  end

  # The stage select's blank option carries the parent's id, so clearing the stage saves the parent competition.
  context "when the stage is cleared" do
    before do
      stored_competition(stage)
      find("#game_stage_id option:first-child").select_option
    end

    it "moves the game back to the parent competition" do
      expect(stored_competition(competition)).to eq(competition)
    end
  end

  # Rebuilding the stage list fires no stage save, so the new parent is what stays.
  context "when the parent changes while a stage is set" do
    before do
      stored_competition(stage)
      select "Кубок Зимы", from: "game_competition_id"
    end

    it "moves the game to the new parent competition" do
      expect(stored_competition(other_competition)).to eq(other_competition)
    end
  end
end
