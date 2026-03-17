require "rails_helper"

RSpec.describe "Player profile" do
  let_it_be(:player) { create(:player, name: "Алексей") }
  let_it_be(:season_competition) { create(:competition, :season, name: "Сезон 5") }
  let_it_be(:series_competition) { create(:competition, :series, parent: season_competition) }
  let_it_be(:game) do
    create(:game, competition: series_competition, game_number: 1,
           played_on: Date.new(2025, 1, 10))
  end
  let_it_be(:participation) { create(:game_participation, game:, player:, plus: 3.0, minus: 0.5, win: true) }
  let_it_be(:award) { create(:award, title: "Лучший игрок", staff: false) }
  let_it_be(:player_award) { create(:player_award, player:, award:, season: 5) }

  before { visit player_path(player) }

  it "displays player name" do
    expect(page).to have_content("Алексей")
  end

  it "displays per-competition stats" do
    expect(page).to have_content("Сезон 5")
  end

  it "links to games in the game history" do
    expect(page).to have_link(href: game_path(game))
  end

  it "displays awards" do
    expect(page).to have_content("Лучший игрок")
  end
end
