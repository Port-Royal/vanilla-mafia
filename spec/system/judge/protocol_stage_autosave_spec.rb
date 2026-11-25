require "rails_helper"

RSpec.describe "Protocol stage autosave" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:competition) { create(:competition, :tournament, name: "Кубок Осени") }
  let_it_be(:stage) { create(:competition, :round, parent: competition, name: "Финал") }
  let_it_be(:game) { create(:game, competition: competition) }

  let(:stored_competition) do
    page.document.synchronize do
      stored = game.reload.competition
      raise Capybara::ExpectationNotMet, "stage not saved yet: #{stored.name}" unless stored == stage

      stored
    end
  end

  before do
    sign_in admin
    visit edit_judge_protocol_path(game)
    click_button I18n.t("game_protocols.autosave.toggle_off")
  end

  context "when a stage is picked" do
    before { select "Финал", from: "game_stage_id" }

    it "moves the game to the stage" do
      expect(stored_competition).to eq(stage)
    end
  end
end
